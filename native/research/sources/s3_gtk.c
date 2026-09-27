//
// shoes/native-gtk.c
// GTK+ code for Shoes.
//   Modified for Gtk-3.0 by Cecil Coupe (cjc)
//
#ifndef GTK3
// fail only used for shoes_native_window_color will be deleted
#define GTK3
#endif
#include "shoes/app.h"
#include "shoes/ruby.h"
#include "shoes/config.h"
#include "shoes/world.h"
#include "shoes/types/settings.h"
#include "shoes/native/native.h"
#include "shoes/types/native.h"
#include "shoes/types/color.h"
#include "shoes/types/text.h"
#include "shoes/types/text_link.h"
#include "shoes/types/download.h"
#include "shoes/types/event.h"
#include "shoes/internal.h"
#include "shoes/types/menubar.h"
#include "shoes/native/gtk/gtkmenus.h"


#include <fontconfig/fontconfig.h>
#ifndef RUBY_HTTP
#ifndef SHOES_GTK_WIN32
#include <curl/curl.h>
#endif
#endif
#include <pthread.h>
#include <glib/gprintf.h>

#include "gtk.h"
#include "shoes/native/gtk/gtkfixedalt.h"
#include "shoes/native/gtk/gtkentryalt.h"
#include "shoes/native/gtk/gtkcomboboxtextalt.h"
#include "shoes/native/gtk/gtkbuttonalt.h"
#include "shoes/native/gtk/gtkscrolledwindowalt.h"
#include "shoes/native/gtk/gtkprogressbaralt.h"

#define HEIGHT_PAD 0

#define SHOES_GTK_INVISIBLE_CHAR (gunichar)0x2022

/* forward declares in this file */
static void shoes_app_gtk_size_menu(GtkWidget *widget, cairo_t *cr, gpointer data);
static void shoes_canvas_gtk_size_menu(GtkWidget *widget, GtkAllocation *size, gpointer data);

// Is mainloop poll()/select() or Timeout driven
#if defined(SHOES_GTK_WIN32) && ( !defined(GPOLL))
#define SGTMO
#else
#define SGPOLL 
#endif

#ifdef SHOES_GTK_WIN32
int shoes_win10_gtk3_22_check();  // forward declare
#endif
/* 
 * Sigh. We need to accommodate Gnome Shells that "augment* the title bar
 * and/or provide a half baked global menu bar. Like Fedora 29 - but it's not
 * the only distro (Elementary) and it won't be the last. Not a global, yet.
*/
enum {
  OLD_SCHOOL,
  WAYLAND,
};

static int shoes_gtk_backend = OLD_SCHOOL;
/*
int shoes_gtk_set_desktop() {
  char *session = getenv("XDG_SESSION_TYPE");
  char *backend = getenv("GDK_BACKEND"); // not set normally.
  //if (gtk_get_minor_version() >= 24)
    //shoes_gtk_desktop |= GTK_3_24;
  if (session && strcmp(session, "wayland") == 0)
    shoes_gtk_desktop |= WAYLAND;
  if (backend && strcmp(backend,"wayland") == 0)
    shoes_gtk_desktop |= WAYLAND;
  printf("desktop: %s %s %d\n", backend, session, shoes_gtk_desktop);
>>>>>>> ddb8dccbbc29d3cdb3100f564804abd54aaeb5ec
}
*/
// ---------- fonts ------------

static VALUE shoes_make_font_list(FcFontSet *fonts, VALUE ary) {
    int i = 0;
    //printf("fontconfig says %d fonts\n", fonts->nfont);
    for (i = 0; i < fonts->nfont; i++) {
        FcValue val;
        FcPattern *p = fonts->fonts[i];
        if (FcPatternGet(p, FC_FAMILY, 0, &val) == FcResultMatch) {
            rb_ary_push(ary, rb_str_new2((char *)val.u.s));
            //printf("fc says %s\n", (char *)val.u.s);
        }    
    }
    rb_funcall(ary, rb_intern("uniq!"), 0);
    rb_funcall(ary, rb_intern("sort!"), 0);
    return ary;
}

#ifdef SHOES_GTK_WIN32
/*
 * This is only called when a shoe script uses the font(filename) command
 * so the file name is lacuna.ttf, coolvetica.ttf (Shoes splash for the
 * Shoes manual) or a user supplied font
*/
VALUE shoes_load_font(const char *filename) {
    VALUE allfonts, newfonts, oldfonts;
   // the Shoes api says after a font load, return an array of the font
    // name(s). FamilyName in font-speak.
    // The Shoes fontlist must be updated as side effect
    
    // Use the much faster Windows api. First remove the font if it
    // exists in Windows session space - otherwise you won't get a reload without
    // rebooting. Fun.
    int i = 0;
    while( RemoveFontResourceExA( filename, FR_PRIVATE, 0 ) )
    {
      i++;
    }

    if (i) {
      printf("removed %s %d times\n", filename, i);
    }

    int fonts = AddFontResourceExA(filename, FR_PRIVATE, 0);
    if (fonts == 0) {
      printf("windows failed to add fonts in %s\n", filename);
      return Qnil;
    }
    allfonts = shoes_font_list();   // everything, include the one loaded
    oldfonts = rb_const_get(cShoes, rb_intern("FONTS"));
    newfonts = rb_funcall(allfonts, rb_intern("-"), 1, oldfonts);
    shoes_update_fonts(allfonts);
    return newfonts;
}


static int CALLBACK shoes_font_list_iter(const ENUMLOGFONTEX *font, const NEWTEXTMETRICA *pfont, DWORD type, LPARAM l) {
    rb_ary_push(l, rb_str_new2(font->elfLogFont.lfFaceName));
    return TRUE;
}

VALUE shoes_font_list() {
    LOGFONT font = {0, 0, 0, 0, 0, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 0, 0, ""};
    VALUE ary = rb_ary_new();
    HDC dc = GetDC(NULL);
    EnumFontFamiliesExA(dc, &font, (FONTENUMPROC)shoes_font_list_iter, (LPARAM)ary, 0);
    ReleaseDC(NULL, dc);
    rb_funcall(ary, rb_intern("uniq!"), 0);
    rb_funcall(ary, rb_intern("sort!"), 0);
    return ary;
}

#else  // Linux gtk3
#if 0
// Fontconfig list
VALUE shoes_font_list() {
    VALUE ary = rb_ary_new();
    FcConfig *fc = FcConfigGetCurrent();
    FcFontSet *fonts = FcConfigGetFonts(fc, FcSetApplication);
    if (fonts) shoes_make_font_list(fonts, ary);
    fonts = FcConfigGetFonts(fc, FcSetSystem);
    if (fonts) shoes_make_font_list(fonts, ary);
    return ary;
}

VALUE shoes_load_font(const char *filename) {
    FcConfig *fc = FcConfigGetCurrent();
    FcFontSet *fonts = FcFontSetCreate();
    if (!FcFileScan(fonts, NULL, NULL, NULL, (const FcChar8 *)filename, FcTrue))
        return Qnil;

    VALUE ary = rb_ary_new();
    shoes_make_font_list(fonts, ary);  // This is usually just 1 font
    FcFontSetDestroy(fonts);

    if (!FcConfigAppFontAddFile(fc, (const FcChar8 *)filename))
        return Qnil;

    // refresh the FONTS list
    shoes_update_fonts(shoes_font_list());
    return ary;
}
#else
// Pango list from https://www.lemoda.net/pango/list-fonts/index.html
VALUE shoes_font_list() {
    int i;
    PangoFontFamily ** families;
    int n_families;
    PangoFontMap * fontmap;
    VALUE ary = rb_ary_new();

    fontmap = pango_cairo_font_map_get_default();
    pango_font_map_list_families (fontmap, & families, & n_families);
    //printf ("There are %d families\n", n_families);
    for (i = 0; i < n_families; i++) {
        PangoFontFamily * family = families[i];
        const char * family_name;

        family_name = pango_font_family_get_name (family);
        //printf ("Family %d: %s\n", i, family_name);
        rb_ary_push(ary, rb_str_new2(family_name));
    }
    g_free (families);
    return ary;
}

VALUE shoes_load_font(const char *filename) {
    FcConfig *fc = FcConfigGetCurrent();
    FcFontSet *fonts = FcFontSetCreate();
    if (!FcFileScan(fonts, NULL, NULL, NULL, (const FcChar8 *)filename, FcTrue)) {
        return Qnil;
    }

    VALUE ary = rb_ary_new();
    // should have a pango version below, eh?
    shoes_make_font_list(fonts, ary);
    FcFontSetDestroy(fonts);

    if (!FcConfigAppFontAddFile(fc, (const FcChar8 *)filename)) {
        return Qnil;
    }

    // refresh the FONTS list
    shoes_update_fonts(shoes_font_list());
    return ary;
}
#endif // Pango version
#endif // Windows or Not

/*
 * Shoes 3.3.4+ may use gtk_application_new (aka GApplication) instead of gtk_init
*/

void
shoes_gtk_app_activate (GApplication *app, gpointer user_data) {
    fprintf(stderr, "shoes_gtk_app_activate called\n");
}

void shoes_gtk_app_open (GApplication *app, GFile **files,
      gint n_files, gchar *hint) {
    fprintf(stderr, "shoes_gtk_app_open called\n");
}

gboolean
shoes_gtk_app_startup(GApplication *application, gpointer user_data) {
    fprintf(stderr, "shoes_gtk_app_startup\n");
    return TRUE;
}

gboolean
shoes_gtk_app_cmdline (GApplication *application, gchar ***arguments, gint *exit_status)
{
  /* This doesn't seem to work as documented.
   * *exit_status is 0x0 instead of a real pointer, arguments don't seem
   * correct either. For Shoes it doesn't matter. Just tell gtk we processed
   * them so it doesn't have too. Need to do this for Gtk/Windows which has the
   * documented habit of reading the commandline twice
  */ 
  printf("command-line signal processed\n");
  return TRUE;
}


// Some globals for Gtk3 
GtkApplication *shoes_GtkApp; 

GtkCssProvider *shoes_css_provider = NULL; // user provided theme

void shoes_gtk_css_error(GtkCssProvider *provider,
                         GtkCssSection  *section,
                         GError         *error,
                         gpointer        user_data) 
{
  fprintf(stderr,"%s\n", error->message);
}

// Process the setting for Theme and css 
// TODO: path handling is not unicode friendly
void shoes_gtk_load_css(shoes_settings *st) {
  char theme_path[100];
  if (! NIL_P(st->theme)) {
      // A theme was requested in shoes.yaml
      sprintf(theme_path, "themes/%s/gtk-3.0/gtk.css", RSTRING_PTR(st->theme));
      st->theme_path = rb_str_new2(theme_path);
  } else { 
    // user space theme?
    char dflt[100];
#ifdef SHOES_GTK_WIN32
    // TODO (home and appdata and ) Beware the file.separator in mingw C
    char *home = getenv("HOME");
    sprintf(dflt,"%s/AppData/Local/Shoes/themes/default", home);
#else
    char *home = getenv("HOME");
    sprintf(dflt,"%s/.shoes/themes/default", home);
#endif
    FILE *df = fopen(dflt, "r");
    if (df) {
      char ln[60];
      fgets(ln, 59, df);
      // Trim \n from ln
      char *p = strrchr(ln, '\n');
      if (p) {
          *p = '\0';
      }
      st->theme = rb_str_new2(ln);
      fclose(df);
      // now build the path to gtk.css
      char *pos = strrchr(dflt, '/');
      *pos = '\0';
      char css[100];
      sprintf(css,"%s/%s/gtk-3.0/gtk.css",dflt,ln);
      st->theme_path = rb_str_new2(css);
    } else {
      // this is expected for most users - no themes
      return;
    }
  }
  if (!NIL_P(st->theme) && !NIL_P(st->theme_path)) {
    strcpy(theme_path, RSTRING_PTR(st->theme_path));
    FILE *th = fopen(theme_path, "r");
    if (th) {
      printf("make a css provider from %s\n", theme_path);
      fclose(th);
      // gtk_css_provider_load_from_path(...)
      GError *gerr = NULL;
      shoes_css_provider = gtk_css_provider_new();
      g_signal_connect(G_OBJECT(shoes_css_provider), "parsing-error",
                       G_CALLBACK(shoes_gtk_css_error), NULL);
 
      int err = gtk_css_provider_load_from_path(shoes_css_provider, theme_path, &gerr);
      if (gerr != NULL) {
        fprintf(stderr, "Failed css load:css %s\n", gerr->message);
        g_error_free(gerr);
      }
    } else {
      fprintf(stderr, "theme %s not found\n",theme_path);
    }
  }
}

void shoes_native_init() {
#if !defined(RUBY_HTTP) && !defined(SHOES_GTK_WIN32)
    curl_global_init(CURL_GLOBAL_ALL);
#endif

    int status;
    shoes_settings *st;
    Data_Get_Struct(shoes_world->settings, shoes_settings, st);
    char app_id[100];
    char *rdom = RSTRING_PTR(st->rdomain);
    if (st->mdi == Qtrue) {
      sprintf(app_id, "%s",rdom); 
    } else {
      sprintf(app_id, "%s%d", rdom, getpid()); // TODO: Windows?
    }
    // set the gdk_backend 
    //char *csd = getenv("GTK_CSD");
    //printf("csd = %s\n", csd);
    if (st->backend != Qnil) {
      char *backend = RSTRING_PTR(st->backend);
      gdk_set_allowed_backends(backend);
      if (strncmp(backend, "wayland", 7) == 0) {
        printf("setting wayland backend\n");
        shoes_gtk_backend = shoes_gtk_backend | WAYLAND;
      }
    } else {
       // defaults to shoes_gtk_backend == OLD_SCHOOL
#ifdef SHOES_GTK_WIN32
       gdk_set_allowed_backends("win32,x11");
       // TODO: believe it or not - Gtk3.22.7 has a bug? on win10 
       if (shoes_win10_gtk3_22_check()) {
            shoes_gtk_backend = shoes_gtk_backend | WAYLAND;
       }
#endif 
#ifdef SHOES_QUARTZ
      gdk_set_allowed_backends("quartz,x11");
#endif 
#if defined(SHOES_GTK) && !defined(SHOES_GTK_WIN32)
      gdk_set_allowed_backends("x11,wayland,mir");
#endif
    }
    //fprintf(stderr,"launching %s\n", app_id);
    shoes_GtkApp = gtk_application_new (app_id, G_APPLICATION_HANDLES_COMMAND_LINE);
    // register with dbus
    if (g_application_register((GApplication *)shoes_GtkApp, NULL, NULL)) {
      //fprintf(stderr,"%s is registered\n",app_id);
      st->dbus_name = rb_str_new2(app_id);
    }
    g_signal_connect(shoes_GtkApp, "activate", G_CALLBACK (shoes_gtk_app_activate), NULL);
    g_signal_connect(shoes_GtkApp, "command-line", G_CALLBACK (shoes_gtk_app_cmdline), NULL);
    g_signal_connect(G_APPLICATION(shoes_GtkApp), "startup", G_CALLBACK(shoes_gtk_app_startup), NULL);

    shoes_gtk_load_css(st);

    gtk_init(NULL,NULL); // This starts the gui w/o triggering signals - complains but works.
    // g_application_run(G_APPLICATION(shoes_GtkApp), 0, NULL); // doesn't work but could?
    
#ifdef OLD_STARTUP_UNUSED
    // Shoes < 3.3.6 way to init
    gtk_init(NULL, NULL);
#endif

}
/* end of GApplication init  */

void shoes_native_cleanup(shoes_world_t *world) {
#if !defined(RUBY_HTTP) && !defined(SHOES_GTK_WIN32)
    curl_global_cleanup();
#endif
}

void shoes_native_quit() {
    gtk_main_quit();
}


#ifdef SHOES_GTK_WIN32
int shoes_win32_cmdvector(const char *cmdline, char ***argv) {
//  return rb_w32_cmdvector(cmdline, argv);
    return 0; // TODO: delete this function.
}

void shoes_get_time(SHOES_TIME *ts) {
    *ts = g_get_monotonic_time();  // Should work for GTK3 w/o win32
}

unsigned long shoes_diff_time(SHOES_TIME *start, SHOES_TIME *end) {
    return *end - *start;
}
#else
void shoes_get_time(SHOES_TIME *ts) {
#ifdef SHOES_GTK_OSX
    gettimeofday(ts, NULL);
#else
    clock_gettime(CLOCK_REALTIME, ts);
#endif
}

unsigned long shoes_diff_time(SHOES_TIME *start, SHOES_TIME *end) {
    unsigned long usec;
    if ((end->tv_nsec-start->tv_nsec)<0) {
        usec = (end->tv_sec-start->tv_sec - 1) * 1000;
        usec += (1000000000 + end->tv_nsec - start->tv_nsec) / 1000000;
    } else {
        usec = (end->tv_sec - start->tv_sec) * 1000;
        usec += (end->tv_nsec - start->tv_nsec) / 1000000;
    }
    return usec;
}
#endif

typedef struct {
    unsigned int name;
    VALUE obj;
    void *data;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int ret;
} shoes_gtk_msg;


static gboolean shoes_gtk_catch_message(gpointer user) {
    shoes_gtk_msg *msg = (shoes_gtk_msg *)user;
    pthread_mutex_lock(&msg->mutex);
    msg->ret = shoes_catch_message(msg->name, msg->obj, msg->data);
    pthread_cond_signal(&msg->cond);
    pthread_mutex_unlock(&msg->mutex);
    return FALSE;
}

// Only called by image.c
int shoes_throw_message(unsigned int name, VALUE obj, void *data) {
    int ret;
    shoes_gtk_msg *msg = SHOE_ALLOC(shoes_gtk_msg);
    msg->name = name;
    msg->obj = obj;
    msg->data = data;
    pthread_mutex_init(&msg->mutex, NULL);
    pthread_cond_init(&msg->cond, NULL);
    msg->ret = 0;

    pthread_mutex_lock(&msg->mutex);
    g_idle_add_full(G_PRIORITY_DEFAULT, shoes_gtk_catch_message, msg, NULL);
    pthread_cond_wait(&msg->cond, &msg->mutex);
    ret = msg->ret;
    pthread_mutex_unlock(&msg->mutex);

    free(msg);
    return ret;
}

void shoes_native_slot_mark(SHOES_SLOT_OS *slot) {}
void shoes_native_slot_reset(SHOES_SLOT_OS *slot) {}
void shoes_native_slot_clear(shoes_canvas *canvas) {
    if (canvas->slot->vscroll) {
        GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(canvas->slot->vscroll));
        gtk_adjustment_set_value(adj, gtk_adjustment_get_lower(adj));
    }
}

void shoes_native_slot_paint(SHOES_SLOT_OS *slot) {
    gtk_widget_queue_draw(slot->oscanvas);
}

void shoes_native_slot_lengthen(SHOES_SLOT_OS *slot, int height, int endy) {
    if (slot->vscroll) {
        GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(slot->vscroll));
        if (gtk_adjustment_get_upper(adj) != (gdouble)endy) {
            gtk_range_set_range(GTK_RANGE(slot->vscroll), 0., (gdouble)endy);

            if (gtk_adjustment_get_page_size(adj) >= gtk_adjustment_get_upper(adj)) {
                gtk_widget_hide(GTK_WIDGET(slot->vscroll));
            }
            else {
                gtk_widget_show(GTK_WIDGET(slot->vscroll));
            }
        }
    }
}

void shoes_native_slot_scroll_top(SHOES_SLOT_OS *slot) {
    if (slot->vscroll) {
        gtk_range_set_value(GTK_RANGE(slot->vscroll), slot->scrolly);
    }
}

int shoes_native_slot_gutter(SHOES_SLOT_OS *slot) {
    if (slot->vscroll) {
        GtkRequisition rnat;
        gtk_widget_get_preferred_size(GTK_WIDGET(slot->vscroll), NULL, &rnat);
        return rnat.width;
    }

    return 0;
}

void shoes_native_remove_item(SHOES_SLOT_OS *slot, VALUE item, char c) {}

//
// Window-level events
//
static gboolean shoes_app_gtk_motion(GtkWidget *widget, GdkEventMotion *event, gpointer data) {
    GdkModifierType state;
    shoes_app *app = (shoes_app *)data;
    char *current_desktop_session = getenv("XDG_SESSION_TYPE");

    if (!event->is_hint) {
        shoes_canvas *canvas;
        Data_Get_Struct(app->canvas, shoes_canvas, canvas);
        state = (GdkModifierType)event->state;
        int mods = 0;
        
        if (event->state & GDK_SHIFT_MASK) {
          mods = mods | SHOES_MODIFY_SHIFT;
        }
        
        if (event->state & GDK_CONTROL_MASK) {
          mods = mods | SHOES_MODIFY_CTRL;
        }

        int new_x, new_y;
        gtk_widget_translate_coordinates(widget, app->slot->oscanvas, event->x, event->y, &new_x, &new_y);
       if (app->have_menu) {
          shoes_app_motion(app, new_x, new_y + canvas->slot->scrolly, mods);
          //shoes_app_motion(app, (int)event->x, (int)event->y + canvas->slot->scrolly - app->mb_height, mods);
        } else {
          // TODO: Do not Hardcode offsets. 
          if (shoes_gtk_backend & WAYLAND) {
            new_y = max(0,new_y - 60);
            new_x = max(0, new_x - 29);
            //printf("mv: x: %d -> %d y: %d -> %d\n",(int)event->x, new_x, (int)event->y, new_y);
          }
          shoes_app_motion(app, new_x, new_y + canvas->slot->scrolly, mods);
          //shoes_app_motion(app, (int)event->x, (int)event->y + canvas->slot->scrolly, mods);
        }
    }
    return TRUE;
}

#ifdef NEWCLICK
static gboolean shoes_app_gtk_button(GtkWidget *widget, GdkEventButton *event, gpointer data) {
    shoes_app *app = (shoes_app *)data;
    shoes_canvas *canvas;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);
    
    int x, y;
    GdkModifierType state;
   
    gdk_window_get_device_position(gtk_widget_get_window(widget), event->device, &x, &y, &state);
    
    if (event->type == GDK_BUTTON_PRESS) {
        shoes_app_click(app, event->button, x, y);
    } else if (event->type == GDK_BUTTON_RELEASE) {
        shoes_app_release(app, event->button, x, y);
    }
    return TRUE;
}
#else
static gboolean shoes_app_gtk_button(GtkWidget *widget, GdkEventButton *event, gpointer data) {
    shoes_app *app = (shoes_app *)data;
    shoes_canvas *canvas;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);
    // process modifiers
    int mods = 0;
    if (event->state & GDK_SHIFT_MASK)
      mods = mods | SHOES_MODIFY_SHIFT;
    if (event->state & GDK_CONTROL_MASK)
      mods = mods | SHOES_MODIFY_CTRL; 
/*  never get these on Linux or its a themeable thing
    if (event->state & GDK_MOD1_MASK)  
      mods = mods | SHOES_MODIFY_ALT;
    if (event->state & GDK_SUPER_MASK)
      fprintf(stderr, "super\n");
    if (event->state & GDK_HYPER_MASK)
      fprintf(stderr, "hyper\n");   
    if (event->state & GDK_META_MASK)
      fprintf(stderr, "meta\n");   
*/
 		int new_x, new_y;
		gtk_widget_translate_coordinates(widget, app->slot->oscanvas, event->x, event->y, &new_x, &new_y);
    if (event->type == GDK_BUTTON_PRESS) {
      if (app->have_menu) {
        //shoes_app_click(app, event->button, event->x, event->y + canvas->slot->scrolly - app->mb_height, mods);
        shoes_app_click(app, event->button, new_x, new_y + canvas->slot->scrolly, mods);
      } else {
        // TODO: Do not Hardcode offsets. Windows? Different Theme?
        //if (gtk_get_minor_version() >= 24 && strcmp(current_desktop_session, "wayland") == 0) { // 3.24.x
        if (shoes_gtk_backend & WAYLAND) { 
          new_y = max(0,new_y - 60);
          new_x = max(0, new_x - 29);
          //printf("btn: x: %d -> %d y: %d -> %d\n",(int)event->x, new_x, (int)event->y, new_y);
        }
        shoes_app_click(app, event->button, new_x, new_y + canvas->slot->scrolly, mods);
        //shoes_app_click(app, event->button, event->x, event->y + canvas->slot->scrolly, mods);
      }
    } else if (event->type == GDK_BUTTON_RELEASE) {
      if (app->have_menu) {
        shoes_app_release(app, event->button, new_x, new_y + canvas->slot->scrolly, mods);
      } else {
        shoes_app_release(app, event->button, new_x, new_y + canvas->slot->scrolly, mods);
      }
    }
    return TRUE;
}
#endif

static gboolean shoes_app_gtk_wheel(GtkWidget *widget, GdkEventScroll *event, gpointer data) {
    ID wheel;
    shoes_app *app = (shoes_app *)data;
    char *current_desktop_session = getenv("XDG_SESSION_TYPE");

    switch (event->direction) {
        case GDK_SCROLL_UP:
            wheel = s_up;
            break;
        case GDK_SCROLL_DOWN:
            wheel = s_down;
            break;
        case GDK_SCROLL_LEFT:
            wheel = s_left;
            break;
        case GDK_SCROLL_RIGHT:
            wheel = s_right;
            break;
        default:
            return TRUE;
    }
    // process modifiers
    int mods = 0;
    if (event->state & GDK_SHIFT_MASK) {
      mods = mods | SHOES_MODIFY_SHIFT;
    }
    if (event->state & GDK_CONTROL_MASK)
      mods = mods | SHOES_MODIFY_CTRL; 
 		int new_x, new_y;
		gtk_widget_translate_coordinates(widget, app->slot->oscanvas, event->x, event->y,
			&new_x, &new_y);
    if (app->have_menu) {
      shoes_app_wheel(app, wheel, event->x, event->y - app->mb_height, mods);
    }
    else {
      if (shoes_gtk_backend & WAYLAND) {
        new_y = max(0,new_y - 60);
        new_x = max(0, new_x - 29);
        //printf("whl: x: %d -> %d y: %d -> %d\n",(int)event->x, new_x, (int)event->y, new_y);
      }
      shoes_app_wheel(app, wheel, event->x, event->y, mods);
    }
    return TRUE;
}

#if 0
// TODO: unused? called when window was maximized (window adornment button)
// considered to be a hack.
static void shoes_gtk_resized_max(shoes_app *app, int width, int height) {
    shoes_canvas *canvas;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);
#ifdef SZBUG
    fprintf(stderr,"shoes_gtk_resized_max: %d %d\n", width, height);
#endif
    if (canvas->slot->vscroll &&
            (height != canvas->slot->scrollh || width != canvas->slot->scrollw)) {
        GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(canvas->slot->vscroll));
        //gtk_widget_set_size_request(canvas->slot->vscroll, -1, height);
        gtk_widget_set_size_request(canvas->slot->vscroll, -1, height);

        //gtk_widget_set_size_request(GTK_CONTAINER(widget), canvas->app->width, size->height);
        GtkAllocation alloc;
        gtk_widget_get_allocation((GtkWidget *)canvas->slot->vscroll, &alloc);  
#ifdef SZBUG
       fprintf(stderr, "alloc: %d %d %d %d\n\n", alloc.x, alloc.y, alloc.width, alloc.height);
#endif
        gtk_fixed_move(GTK_FIXED(canvas->slot->oscanvas), canvas->slot->vscroll,
                    (width - alloc.width)-100, 0);
        gtk_adjustment_set_page_size(adj, height);
        gtk_adjustment_set_page_increment(adj, height - 32);

        if (gtk_adjustment_get_page_size(adj) >= gtk_adjustment_get_upper(adj))
            gtk_widget_hide(canvas->slot->vscroll);
        else {
            gtk_widget_show(canvas->slot->vscroll);
        }
        canvas->slot->scrollh = height;
        canvas->slot->scrollw = width;
    }
}
#endif

// called only by **Window** signal handler for "size-allocate"
static void shoes_app_gtk_size(GtkWidget *widget, cairo_t *cr, gpointer data) {
    shoes_app *app = (shoes_app *)data;
    gtk_window_get_size(GTK_WINDOW(app->os.window), &app->width, &app->height);
#ifdef SZBUG
    fprintf(stderr,"shoes_app_gtk_size: wid: %d hgt: %d\n", app->width, app->height);
#if 0 // only exists in gtk 3.12 and above which aint' windows
    if (gtk_window_is_maximized(widget)) {
      // because of maimize button and asynch behaviour app->w/h are incorrect here.
      fprintf(stderr,"resized max %d, %d\n", app->width, app->height);
    }
#endif
#endif
    // This calls shoes_native_canvas_resize - a no-opp in gtk
    shoes_canvas_size(app->canvas, app->width, app->height);
}

#define KEY_SYM(name, sym) \
  else if (event->keyval == GDK_KEY_##name) \
    v = ID2SYM(rb_intern("" # sym))

static gboolean shoes_app_gtk_keypress(GtkWidget *widget, GdkEventKey *event, gpointer data) {
    VALUE v = Qnil;
    guint modifiers = event->state;
    shoes_app *app = (shoes_app *)data;
    if (event->keyval == GDK_KEY_Return) {
        v = rb_str_new2("\n");
    }
    KEY_SYM(BackSpace, backspace);	// GTK3 <bs> has length of 1. Go figure.
    KEY_SYM(Escape, escape);
    else if (event->length > 0) {
        if ((event->state & GDK_CONTROL_MASK) || (event->state & GDK_MOD1_MASK)) {
            gint len;
            gunichar ch;
            char chbuf[7] = {0};

            ch = gdk_keyval_to_unicode(event->keyval);
            len = g_unichar_to_utf8(ch, chbuf);
            chbuf[len] = '\0';

            v = ID2SYM(rb_intern(chbuf));
            if (modifiers & GDK_SHIFT_MASK) {
              modifiers ^= GDK_SHIFT_MASK;
            }
        } else {
            if (event->string[0] == '\r' && event->length == 1) {
                v = rb_str_new2("\n");
            }
            else {
                v = rb_str_new(event->string, event->length);
            }
        }
    }
    KEY_SYM(Insert, insert);
    KEY_SYM(Delete, delete);
    KEY_SYM(Tab, tab);
    KEY_SYM(ISO_Left_Tab, tab);
    KEY_SYM(Page_Up, page_up);
    KEY_SYM(Page_Down, page_down);
    KEY_SYM(Home, home);
    KEY_SYM(End, end);
    KEY_SYM(Left, left);
    KEY_SYM(Up, up);
    KEY_SYM(Right, right);
    KEY_SYM(Down, down);
    KEY_SYM(F1, f1);
    KEY_SYM(F2, f2);
    KEY_SYM(F3, f3);
    KEY_SYM(F4, f4);
    KEY_SYM(F5, f5);
    KEY_SYM(F6, f6);
    KEY_SYM(F7, f7);
    KEY_SYM(F8, f8);
    KEY_SYM(F9, f9);
    KEY_SYM(F10, f10);
    KEY_SYM(F11, f11);
    KEY_SYM(F12, f12);

    if (v != Qnil) {
        if (event->type == GDK_KEY_PRESS) {
            shoes_app_keydown(app, v);

            if (event->keyval == GDK_KEY_Return)
                if ((event->state & (GDK_SHIFT_MASK | GDK_CONTROL_MASK | GDK_MOD1_MASK)) != 0)
                    v = ID2SYM(rb_intern("enter"));

            if (SYMBOL_P(v)) {
                if (modifiers & GDK_MOD1_MASK) {
                    KEY_STATE(alt);
                }
                if (modifiers & GDK_SHIFT_MASK) {
                    KEY_STATE(shift);
                }
                if (modifiers & GDK_CONTROL_MASK) {
                    KEY_STATE(control);
                }
            }

            shoes_app_keypress(app, v);
        } else {
            shoes_app_keyup(app, v);
        }
    }

    return FALSE;
}

static gboolean shoes_app_gtk_quit(GtkWidget *widget, GdkEvent *event, gpointer data) {
    shoes_app *app = (shoes_app *)data;
    if (shoes_app_remove(app)) {
        gtk_main_quit();
    }

    return FALSE;
}

static void shoes_canvas_gtk_paint_children(GtkWidget *widget, gpointer data) {
    shoes_canvas *canvas = (shoes_canvas *)data;
    gtk_container_propagate_draw(GTK_CONTAINER(canvas->slot->oscanvas), widget,
                                 canvas->slot->drawevent);
}

static void shoes_canvas_gtk_paint(GtkWidget *widget, cairo_t *cr, gpointer data) {
    VALUE c = (VALUE)data;
    shoes_canvas *canvas;
    Data_Get_Struct(c, shoes_canvas, canvas);
    canvas->slot->drawevent = cr;		// stash it for the children

    // getting widget dirty area, already clipped
    cairo_rectangle_int_t rect;
    gdk_cairo_get_clip_rectangle(cr, &rect);

    shoes_canvas_paint(c);
    // Gtk3 doc says gtk_container_foreach is preferable over gtk_container_forall
    gtk_container_foreach(GTK_CONTAINER(widget), shoes_canvas_gtk_paint_children, canvas);

    canvas->slot->drawevent = NULL;
}

static void shoes_canvas_gtk_size(GtkWidget *widget, GtkAllocation *size, gpointer data) {
    VALUE c = (VALUE)data;
    shoes_canvas *canvas;
    Data_Get_Struct(c, shoes_canvas, canvas);
#ifdef SZBUG
    fprintf(stderr,"shoes_canvas_gtk_size: %d %d %d %d\n", size->x, size->y, size->width, size->height);
#endif
    if (canvas->slot->vscroll &&
            (size->height != canvas->slot->scrollh || size->width != canvas->slot->scrollw)) {
        GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(canvas->slot->vscroll));
        gtk_widget_set_size_request(GTK_WIDGET(canvas->slot->vscroll), -1, size->height);
        
        //gtk_widget_set_size_request(GTK_CONTAINER(widget), canvas->app->width, size->height);
        GtkAllocation alloc;
        gtk_widget_get_allocation(GTK_WIDGET(canvas->slot->vscroll), &alloc);  
#ifdef SZBUG
        fprintf(stderr, "alloc: %d %d %d %d\n\n", alloc.x, alloc.y, alloc.width, alloc.height);
#endif
        if (canvas->slot->oscanvas != widget) {
          fprintf(stderr,"shoes_canvas_gtk_size: ooops\n");
        }
          
        gtk_fixed_move(GTK_FIXED(canvas->slot->oscanvas), canvas->slot->vscroll,
                       size->width - alloc.width, 0);
        gtk_adjustment_set_page_size(adj, size->height);
        gtk_adjustment_set_page_increment(adj, size->height - 32);

        if (gtk_adjustment_get_page_size(adj) >= gtk_adjustment_get_upper(adj))
            gtk_widget_hide(canvas->slot->vscroll);
        else {
            gtk_widget_show(canvas->slot->vscroll);
        }
        canvas->slot->scrollh = size->height;
        canvas->slot->scrollw = size->width;
    }
}

static void shoes_canvas_gtk_scroll(GtkRange *r, gpointer data) {
    VALUE c = (VALUE)data;
    shoes_canvas *canvas;
    Data_Get_Struct(c, shoes_canvas, canvas);
    canvas->slot->scrolly = (int)gtk_range_get_value(r);
    shoes_slot_repaint(canvas->app->slot);
}

/* ----------- mainloop handling -------------- */

/*
 * Some notes about select and the gtk mainloop
 * select() blocks the calling thread (Gtk) until the fds are ready 
 * OR the timeout expires. In Shoes, there maybe other ruby threads running
 * because of user requests (download is threaded). Thise threads won't block
 * HERE but there work could unblock one of the fds that select() is waiting
 * on - that would wake the GUI up (as does the timeout)
*/
#ifdef SGPOLL
#ifndef SHOES_GTK_WIN32
static gint shoes_app_g_poll(GPollFD *fds, guint nfds, gint timeout) {
    struct timeval tv;

    rb_fdset_t rset, wset, xset;
    GPollFD *f;
    int ready;
    int maxfd = 0;

    rb_fd_init(&rset); // was FD_ZERO()
    rb_fd_init(&wset);
    rb_fd_init(&xset);

    for (f = fds; f < &fds[nfds]; ++f)
        if (f->fd >= 0) {
            if (f->events & G_IO_IN) {
                //FD_SET (f->fd, &rset);
                rb_fd_set(f->fd, &rset);
            }
            if (f->events & G_IO_OUT) {
                //FD_SET (f->fd, &wset);
                rb_fd_set(f->fd, &wset);
            }
            if (f->events & G_IO_PRI) {
                //FD_SET (f->fd, &xset);
                rb_fd_set(f->fd, &xset);
            }
            if (f->fd > maxfd && (f->events & (G_IO_IN|G_IO_OUT|G_IO_PRI))) {
                maxfd = f->fd;
            }
        }

    //
    // If we poll indefinitely, then the window updates will
    // pile up for as long as Ruby is churning away.
    //
    // Give Ruby half-seconds in which to work, in order to
    // keep it from completely blocking the GUI.

    if (timeout == -1 || timeout > 500)
        timeout = 500;

    tv.tv_sec = timeout / 1000;
    tv.tv_usec = (timeout % 1000) * 1000;

    ready = rb_thread_fd_select (maxfd + 1, &rset, &wset, &xset, &tv);
    if (ready > 0)
        for (f = fds; f < &fds[nfds]; ++f) {
            f->revents = 0;
            if (f->fd >= 0) {
                //if (FD_ISSET (f->fd, &rset))
                if (rb_fd_isset (f->fd, &rset)) {
                    f->revents |= G_IO_IN;
                }
                //if (FD_ISSET (f->fd, &wset))
                if (rb_fd_isset (f->fd, &wset)) {
                    f->revents |= G_IO_OUT;
                }
                //if (FD_ISSET (f->fd, &xset))
                if (rb_fd_isset (f->fd, &xset)) {
                    f->revents |= G_IO_PRI;
                }
            }
        }
    // Free the allocated storage from rb_fd_init
    rb_fd_term(&rset);
    rb_fd_term(&wset);
    rb_fd_term(&xset);
    return ready;
}
#else
/*
 * Windows: Gtk and Ruby could differ on what an 'fd' is? They could differ
 * in what the bit flags are for events and revents. Since we are polling
 * ruby primarily we need to use it's definitions/macros of C library things
 * 
 * NOTE: as of July 13, 2018 this doesn't crash - also doesn't work well
 * 
*/

static gint shoes_app_g_poll(GPollFD *fds, guint nfds, gint timeout) {
    struct timeval tv;
    fd_set rset, wset, xset; 
    GPollFD *f;
    int ready;
    int maxfd = 0;

    FD_ZERO(&rset); 
    FD_ZERO(&wset);
    FD_ZERO(&xset);

    int i;
    // In Windows/Gtk, GPollFD->fd could be a handle (Gtk/Gio/glib), or a small int (ruby)
    // Watch out for maxfd - it's wrong, according to select() doc.
    for (i = 0; i < nfds; i++) {
        f = &fds[i];
        if (f->fd >= 0) {
            if (f->events & G_IO_IN) {
                FD_SET(f->fd, &rset);
            }
            if (f->events & G_IO_OUT) {
                FD_SET(f->fd, &wset);
            }
            if (f->events & G_IO_PRI) {
                FD_SET(f->fd, &xset);
            }
            if (f->fd > maxfd && (f->events & (G_IO_IN|G_IO_OUT|G_IO_PRI))) {
                maxfd = max (maxfd, i+1);
            }
        }
    }
    //
    // If we poll indefinitely, then the window updates will
    // pile up for as long as Ruby is churning away.
    //
    // Give Ruby half-seconds in which to work, in order to
    // keep it from completely blocking the GUI. 
    //
    // WARNING timeout can be (is) 0 on Windows and Linux
    if (timeout == -1 || timeout > 500) {
        timeout = 500;
    }

    tv.tv_sec = timeout / 1000;
    tv.tv_usec = (timeout % 1000) * 1000;

    //ready = rb_fd_select (maxfd + 1, &rset, &wset, &xset, &tv); // crash
    ready = select (maxfd + 1, &rset, &wset, &xset, &tv); 
    if (ready < 0) {
      // fails a  lot on Windows/Gtk
      // fprintf(stderr, "loop fail\n");
    }
    if (ready > 0) {
        for (f = fds; f < &fds[nfds]; ++f) {
            f->revents = 0;
            if (f->fd >= 0) {
                if (FD_ISSET (f->fd, &rset)) {
                    f->revents |= G_IO_IN;
                }
                if (FD_ISSET (f->fd, &wset)) {
                    f->revents |= G_IO_OUT;
                }
                if (FD_ISSET (f->fd, &xset)) {
                    f->revents |= G_IO_PRI;
                }
            }
        }
    }

    FD_ZERO(&rset);
    FD_ZERO(&wset);
    FD_ZERO(&xset);

    return ready;
}

#endif
#endif

int win_current_tmo = 10;  // only used on Windows until bug is fixed

#ifdef SGTMO
/*static GSource *gtkrb_source;
static GSource *gtkrb_init_source();
static  GSourceFuncs gtkrb_func_tbl;*/
/*
static GSource *gtkrb_init_source()
{
  // fill in the struct
  gtkrb_source = g_source_new(&gtkrb_func_tbl, (guint) sizeof(gtkrb_func_tbl));
}
*/
static int win_default_tmo = 10;

static gboolean gtkrb_idle(gpointer opt) { // opt points to win_current_tmo
    int t = *((int *)opt);
    if (t != win_default_tmo) {
      // change requested - requires new timer
      fprintf(stderr, "new tmo: %d\n", t);
      win_default_tmo = t;
      g_timeout_add(win_default_tmo, gtkrb_idle, &win_current_tmo);
      rb_thread_schedule();
      return 0; // cancel the current(old) timer
    }
    rb_thread_schedule();
    return 1; // keep current timer
}
#endif

void shoes_native_loop() {
#ifdef SGPOLL
    g_main_context_set_poll_func(g_main_context_default(), shoes_app_g_poll);
#else
    /* Win32 (should work for Linux too when finished)
     * Build: struct GSourceFuncs
     * Call: g_source_new() with that struct
     * Call: g_source_attach() with that
     */
#ifdef GIDLE
    //gtkrb_source = gtkrb_init_source();
    //g_source_attach(gtkrb_source, (gpointer) NULL);
    fprintf(stderr,"Using idle loop\n");
    g_idle_add(gtkrb_idle, NULL);
#else
    //fprintf(stderr,"Using timeout loop\n");
    g_timeout_add(win_default_tmo, gtkrb_idle, &win_current_tmo);
#endif
#endif
    GLOBAL_APP(app);
    if (APP_WINDOW(app)) {
         gtk_main();
    }
}

shoes_code shoes_app_cursor(shoes_app *app, ID cursor) {
    if (app->os.window == NULL || gtk_widget_get_window(app->os.window)== NULL || app->cursor == cursor)
        goto done;
    GdkCursor *c;
    if (gtk_get_minor_version() >= 16) {
      // TODO: muliple-moniter support needs? 
      GdkDisplay *dsp = gdk_display_get_default();
      if (cursor == s_hand_cursor || cursor == s_link) {
          c = gdk_cursor_new_for_display(dsp, GDK_HAND2);
      } else if (cursor == s_arrow_cursor) {
          c = gdk_cursor_new_for_display(dsp, GDK_ARROW);
      } else if (cursor == s_text_cursor) {
          c = gdk_cursor_new_for_display(dsp, GDK_XTERM);
      } else if (cursor == s_watch_cursor) {
          c = gdk_cursor_new_for_display(dsp, GDK_WATCH);
      } else
          goto done;
    } else {
      // Windows gtk may be older than 3.16
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
      if (cursor == s_hand_cursor || cursor == s_link) {
          c = gdk_cursor_new(GDK_HAND2);
      } else if (cursor == s_arrow_cursor) {
          c = gdk_cursor_new(GDK_ARROW);
      } else if (cursor == s_text_cursor) {
          c = gdk_cursor_new(GDK_XTERM);
      } else if (cursor == s_watch_cursor) {
          c = gdk_cursor_new(GDK_WATCH);
      } else {
          goto done;
      }
#pragma GCC diagnostic pop
    }
    gdk_window_set_cursor(gtk_widget_get_window(app->os.window), c);
    app->cursor = cursor;

done:
    return SHOES_OK;
}

void shoes_native_app_title(shoes_app *app, char *msg) {
    gtk_window_set_title(GTK_WINDOW(app->os.window), _(msg));
}

void shoes_native_app_resize_window(shoes_app *app) {
    if ((app->os.window != NULL) && (app->width > 0 && app->height > 0)) {
        gtk_window_resize(GTK_WINDOW(app->os.window), app->width, app->height );
    }
}

VALUE shoes_native_get_resizable(shoes_app *app) {
    return gtk_window_get_resizable(GTK_WINDOW(app->os.window));
}

void shoes_native_set_resizable(shoes_app *app, int resizable) {
    gboolean state;
    state = resizable ? TRUE : FALSE;
    if (gtk_window_get_resizable(GTK_WINDOW(app->os.window)) != state) {
        gtk_window_set_resizable(GTK_WINDOW(app->os.window), state);
    }
}


void shoes_native_app_fullscreen(shoes_app *app, char yn) {
    gtk_window_set_keep_above(GTK_WINDOW(app->os.window), (gboolean)yn);
    yn ? gtk_window_fullscreen(GTK_WINDOW(app->os.window)) : gtk_window_unfullscreen(GTK_WINDOW(app->os.window));
}

// new in 3.2.19
void shoes_native_app_set_icon(shoes_app *app, char *icon_path) {
    // replace default icon
    gboolean err;
    GtkWindow *win;
    if (app->have_menu) {
        win = (GtkWindow *)app->os.window;
    }
    else {
        win = (GtkWindow *) app->slot->oscanvas;  // TODO: needed? 
    }
    
    err = gtk_window_set_icon_from_file(win, icon_path, NULL);
    err = gtk_window_set_default_icon_from_file(icon_path, NULL);
}

// new in 3.2.19. TODO 3.3.7 update for use_menu app->os.window
void shoes_native_app_set_wtitle(shoes_app *app, char *wtitle) {
    //gtk_window_set_title(GTK_WINDOW(app->slot->oscanvas), _(wtitle));
    GtkWindow *win;
    if (app->have_menu) {
        win = (GtkWindow *)app->os.window;
    }
    else {
        win = (GtkWindow *) app->slot->oscanvas;  // TODO: needed? 
    }
    
    gtk_window_set_title(GTK_WINDOW(win), _(wtitle));
}

// new in 3.3.3 - opacity  can use the older api on old Gtk3 
void shoes_native_app_set_opacity(shoes_app *app, double opacity) {
  if (gtk_get_minor_version() >= 8) {
      gtk_widget_set_opacity(GTK_WIDGET(app->os.window), opacity);
  }
  else 
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    gtk_window_set_opacity(GTK_WINDOW(app->os.window), opacity);
#pragma GCC diagnostic pop
}

double shoes_native_app_get_opacity(shoes_app *app) {
 if (gtk_get_minor_version() >= 8)
    return gtk_widget_get_opacity(GTK_WIDGET(app->os.window));
  else
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    return gtk_window_get_opacity(GTK_WINDOW(app->os.window));
#pragma GCC diagnostic pop
}

void shoes_native_app_set_decoration(shoes_app *app, gboolean decorated) {
    gtk_window_set_decorated(GTK_WINDOW(app->os.window), decorated);
}

int shoes_native_app_get_decoration(shoes_app *app) {
    return gtk_window_get_decorated(GTK_WINDOW(app->os.window)) == TRUE;
}

// new in 3.3.4
void shoes_native_app_get_window_position(shoes_app *app) {
    gtk_window_get_position(GTK_WINDOW(app->os.window), &app->x, &app->y);
}

void shoes_native_app_window_move(shoes_app *app, int x, int y) {
    gtk_window_move(GTK_WINDOW(app->os.window), app->x = x, app->y = y);
}

/*
 *  All apps windows can have a menubur and then the old shoes space below. 
 *  it's optional and the default is no menu for backwards compatibilty
 *  That causes some pixel tweaking and redundency. 
 */
 
/* TODO fixes bug #349 
 * seems like overkill or incomplete 
*/
#if !GTK_CHECK_VERSION(3,12,0)
// forward declares 
int shoes_gtk_is_maximized(shoes_app *app, int width, int height); 
void shoes_gtk_set_max(shoes_app *app);
#endif
gboolean shoes_app_gtk_configure_event(GtkWidget *widget, GdkEvent *evt, gpointer data) {
  shoes_app *app = (shoes_app *)data;
  if (widget == app->os.window) {  // GtkWindow
    //gtk_widget_set_size_request(widget, evt->configure.width, evt->configure.height);
    shoes_canvas *canvas;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);
#if GTK_CHECK_VERSION(3,12,0)
    if (gtk_window_is_maximized((GtkWindow *)widget)) {
#else
    if (shoes_gtk_is_maximized(app, evt->configure.width, evt->configure.height)) {
#endif
    //if (canvas->slot->vscroll && evt->configure.height != app->height) { 
          GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(canvas->slot->vscroll));
          gtk_widget_set_size_request(GTK_WIDGET(canvas->slot->vscroll), -1, evt->configure.height);
          
          GtkAllocation alloc;
          gtk_widget_get_allocation(GTK_WIDGET(canvas->slot->vscroll), &alloc);  
#ifdef SZBUG
          fprintf(stderr, "shoes_app_gtk_configure_menu %d, %d, %d, %d\n", 
              evt->configure.x, evt->configure.y, evt->configure.width, evt->configure.height);
          fprintf(stderr, "cfg alloc: %d %d %d %d\n\n", alloc.x, alloc.y, alloc.width, alloc.height);
#endif
          gtk_fixed_move(GTK_FIXED(canvas->slot->oscanvas), canvas->slot->vscroll,
                         evt->configure.width - alloc.width, 0);
          gtk_adjustment_set_page_size(adj, evt->configure.height);
          gtk_adjustment_set_page_increment(adj, evt->configure.height - 32);
  
          if (gtk_adjustment_get_page_size(adj) >= gtk_adjustment_get_upper(adj))
              gtk_widget_hide(canvas->slot->vscroll);
          else {
              gtk_widget_show(canvas->slot->vscroll);
          }
      }
  }
  app->width = evt->configure.width;
  app->height = evt->configure.height;
  return FALSE;
}
 
shoes_code shoes_native_app_open(shoes_app *app, char *path, int dialog, shoes_settings *st) {
#if 0 //!defined(SHOES_GTK_WIN32)
    char icon_path[SHOES_BUFSIZE];
    sprintf(icon_path, "%s/static/app-icon.png", shoes_world->path);
    gtk_window_set_default_icon_from_file(icon_path, NULL);
#endif
    GtkWidget *window;       // Root window 
    shoes_app_gtk *gk = &app->os; //lexical - typing shortcut

   char icon_path[SHOES_BUFSIZE];
    if (st->icon_path == Qnil)
      sprintf(icon_path, "%s/static/app-icon.png", shoes_world->path);
    else {
      char *ip = RSTRING_PTR(st->icon_path);
      if (*ip == '/' || ip[1] ==':') {
        strcpy(icon_path, ip);
      }
      else {
       sprintf(icon_path, "%s/%s", shoes_world->path, ip);
      }
    }

    gtk_window_set_default_icon_from_file(icon_path, NULL);

    // The Good old way, menu-less
#if 0
    // don't do this if gtk_init() is used.
    window = gtk_application_window_new(shoes_GtkApp);
#else
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
#endif
    gk->window = window;
    app->slot->oscanvas = window;
    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(window),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
        
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
    if (!app->resizable) {
        gtk_window_resize(GTK_WINDOW(window), app->width, app->height);
        gtk_window_set_resizable(GTK_WINDOW(window), FALSE);
    } else if (app->minwidth < app->width || app->minheight < app->height) {
        GdkGeometry hints;
        hints.min_width = app->minwidth;
        hints.min_height = app->minheight;
#ifdef SZBUG
        fprintf(stderr,"resize hints: %d, %d\n", hints.min_width, hints.min_height);
#endif
        gtk_window_set_geometry_hints(GTK_WINDOW(window), NULL,
                                      &hints, GDK_HINT_MIN_SIZE);
    }
    gtk_window_set_default_size(GTK_WINDOW(window), app->width, app->height);

    gtk_window_get_position(GTK_WINDOW(window), &app->x, &app->y);
    g_signal_connect(G_OBJECT(window), "size-allocate",
                     G_CALLBACK(shoes_app_gtk_size), app);
    g_signal_connect(G_OBJECT(window), "motion-notify-event",
                     G_CALLBACK(shoes_app_gtk_motion), app);
    g_signal_connect(G_OBJECT(window), "button-press-event",
                     G_CALLBACK(shoes_app_gtk_button), app);
    g_signal_connect(G_OBJECT(window), "button-release-event",
                     G_CALLBACK(shoes_app_gtk_button), app);
    g_signal_connect(G_OBJECT(window), "scroll-event",
                     G_CALLBACK(shoes_app_gtk_wheel), app);
    g_signal_connect(G_OBJECT(window), "key-press-event",
                     G_CALLBACK(shoes_app_gtk_keypress), app);
    g_signal_connect(G_OBJECT(window), "key-release-event",
                     G_CALLBACK(shoes_app_gtk_keypress), app);
    g_signal_connect(G_OBJECT(window), "delete-event",
                       G_CALLBACK(shoes_app_gtk_quit), app);
    g_signal_connect(G_OBJECT(window), "configure-event",   // bug #349
                     G_CALLBACK(shoes_app_gtk_configure_event), app);
    
    if (app->fullscreen) shoes_native_app_fullscreen(app, 1);

    gtk_window_set_decorated(GTK_WINDOW(window), app->decorated);
#if GTK_CHECK_VERSION(3,8,0)
    gtk_widget_set_opacity(GTK_WIDGET(window), app->opacity);
#endif
    // ORIG: gtk_widget_set_events(window, GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);
    gtk_widget_add_events(window, GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);


    // If the user asked for a specific Screen (Monitor) for the Window
    if (app->monitor >= 0) {
      shoes_native_monitor_set(app);
    }
#if ! GTK_CHECK_VERSION(3,12,0)
    shoes_gtk_set_max(app);
#endif
    return SHOES_OK;
}

void shoes_native_app_show(shoes_app *app) {
    gtk_widget_show_all(app->os.window);
}


void shoes_native_app_close(shoes_app *app) {
    shoes_app_gtk_quit(app->os.window, NULL, (gpointer)app);
    gtk_widget_destroy(app->os.window);
    app->os.window = NULL;
}

// Below function doesn't work - /etc/alternatives doesn't exist.
// TODO: Appears to not be used at Shoe/ruby level
void shoes_browser_open(char *url) {
    VALUE browser = rb_str_new2("/etc/alternatives/x-www-browser '");
    rb_str_cat2(browser, url);
    rb_str_cat2(browser, "' 2>/dev/null &");
    shoes_sys(RSTRING_PTR(browser), 1);
}

 
void shoes_slot_init(VALUE c, SHOES_SLOT_OS *parent, int x, int y, int width, int height, int scrolls, int toplevel) {
    shoes_canvas *canvas;
    SHOES_SLOT_OS *slot;
    Data_Get_Struct(c, shoes_canvas, canvas);
          
    slot = shoes_slot_alloc(canvas, parent, toplevel);

    /* Subclassing GtkFixed so we can override gtk3 size management which creates
       problems with slot height being always tied to inside widgets cumulative heights
       creating heights overflow with no scrollbar !
    */
    slot->oscanvas = gtkfixed_alt_new(width, height); 
#ifdef SZBUG
    fprintf(stderr,"shoes_slot_init topleve: %d, slot->canvas %lx\n", toplevel, (unsigned long)slot->oscanvas);
#endif
    g_signal_connect(G_OBJECT(slot->oscanvas), "draw",
                     G_CALLBACK(shoes_canvas_gtk_paint), (gpointer)c);

    g_signal_connect(G_OBJECT(slot->oscanvas), "size-allocate",
                     G_CALLBACK(shoes_canvas_gtk_size), (gpointer)c);
    INFO("shoes_slot_init(%lu)\n", c);

    if (toplevel) {
        gtk_container_add(GTK_CONTAINER(parent->oscanvas), slot->oscanvas);
    } else {
        gtk_fixed_put(GTK_FIXED(parent->oscanvas), slot->oscanvas, x, y);
    }
    slot->scrollh = slot->scrollw = 0;
    slot->vscroll = NULL;
    if (scrolls) {
        slot->vscroll = gtk_scrollbar_new(GTK_ORIENTATION_VERTICAL,NULL);
        GtkAdjustment *adj;
        adj = gtk_range_get_adjustment(GTK_RANGE(slot->vscroll));
        gtk_adjustment_set_step_increment(adj, 16);
        gtk_adjustment_set_page_increment(adj, height - 32);
        slot->drawevent = NULL;

        g_signal_connect(G_OBJECT(slot->vscroll), "value-changed",
                         G_CALLBACK(shoes_canvas_gtk_scroll), (gpointer)c);
        gtk_fixed_put(GTK_FIXED(slot->oscanvas), slot->vscroll, -100, -100);

        gtk_widget_set_size_request(GTK_WIDGET(slot->oscanvas), width, height);

        if (!toplevel) { 
            ATTRSET(canvas->attr, wheel, scrolls);
        }
    }

    if (toplevel) {
        shoes_canvas_size(c, width, height);
    }
    else {
        gtk_widget_show_all(slot->oscanvas);
        canvas->width = 100;
        canvas->height = 100;
    }
}

void shoes_slot_destroy(shoes_canvas *canvas, shoes_canvas *pc) {
    if (canvas->slot->vscroll) {
        gtk_container_remove(GTK_CONTAINER(canvas->slot->oscanvas), canvas->slot->vscroll);
    }

    gtk_container_remove(GTK_CONTAINER(pc->slot->oscanvas), canvas->slot->oscanvas);
}

cairo_t *shoes_cairo_create(shoes_canvas *canvas) {
    GdkWindow *win = gtk_widget_get_window(canvas->slot->oscanvas);
    cairo_t *cr = gdk_cairo_create(win);
    if (canvas->slot->drawevent != NULL &&
            gtk_cairo_should_draw_window(canvas->slot->drawevent, win)) {
        cairo_rectangle_int_t alloc;
        gtk_widget_get_allocation((GtkWidget *)canvas->slot->oscanvas, &alloc);
        cairo_region_t *region = cairo_region_create_rectangle(&alloc);
//    cairo_rectangle_int_t w_rect = {canvas->place.ix, canvas->place.iy, canvas->place.w, canvas->place.h};
        cairo_rectangle_int_t w_rect;
        gdk_cairo_get_clip_rectangle(cr, &w_rect);
        cairo_region_intersect_rectangle(region, &w_rect);
        gdk_cairo_region(cr, region);
        cairo_clip(cr);
        cairo_region_destroy(region);

        cairo_translate(cr, alloc.x, alloc.y - canvas->slot->scrolly);
    }
    return cr;
}

void shoes_cairo_destroy(shoes_canvas *canvas) {
}

void shoes_group_clear(SHOES_GROUP_OS *group) {
    //group->radios = NULL;
    //group->layout = NULL;
}

void shoes_native_canvas_place(shoes_canvas *self_t, shoes_canvas *pc) {
    int x, y, newy;

    GtkAllocation a;
    gtk_widget_get_allocation(self_t->slot->oscanvas, &a);
    gtk_widget_translate_coordinates(self_t->slot->oscanvas, pc->slot->oscanvas, 0, 0, &x, &y);
    newy = (self_t->place.iy + self_t->place.dy) - pc->slot->scrolly;

    if (x != self_t->place.ix + self_t->place.dx || y != newy) {
        gtk_fixed_move(
            GTK_FIXED(pc->slot->oscanvas), 
            self_t->slot->oscanvas,
            self_t->place.ix + self_t->place.dx, newy);
    }
    
    if (a.width != self_t->place.iw || a.height != self_t->place.ih) {
        gtk_widget_set_size_request(self_t->slot->oscanvas, self_t->place.iw, self_t->place.ih);
    }
}

void shoes_native_canvas_resize(shoes_canvas *canvas) {
#if 0
  if (canvas->app->have_menu) {
    int w = canvas->width;
    int h = canvas->height;
#ifdef SZBUG
    fprintf(stderr,"shoes_native_canvas_resize: %d, %d\n", w, h);
#endif
    // gtk_widget_queue_resize(canvas->app->os.shoes_window);  // nope
    gtk_widget_set_size_request(canvas->slot->oscanvas, w, h); // won't shrink
    GtkAllocation rect;
    rect.width = w;
    rect.height = h;
    rect.x = 0;
    rect.y = 29;
    //gtk_widget_set_allocation(canvas->slot->oscanvas, &rect); // not as good,
  }
#endif
}

/*
 * one shot timer for start{} on slot. Canvas internal use.
*/
static gboolean start_wait(gpointer data) {
    VALUE rbcanvas = (VALUE)data;
    shoes_canvas *canvas;
    Data_Get_Struct(rbcanvas, shoes_canvas, canvas);

    shoes_safe_block(rbcanvas, ATTR(canvas->attr, start), rb_ary_new3(1, rbcanvas));
    return FALSE; // timeout will be stopped and destroyed
}

void shoes_native_canvas_oneshot(int ms, VALUE canvas) {
    g_timeout_add_full(G_PRIORITY_HIGH, 1, start_wait, (gpointer)canvas, NULL);
}

void shoes_widget_changed(GtkWidget *ref, gpointer data) {
    VALUE self = (VALUE)data;
    shoes_control_send(self, s_change);
}

void shoes_native_control_hide(SHOES_CONTROL_REF ref) {
    gtk_widget_hide(ref);
}

void shoes_native_control_show(SHOES_CONTROL_REF ref) {
    gtk_widget_show(ref);
}

void shoes_native_control_position(SHOES_CONTROL_REF ref, shoes_place *p1, VALUE self,
                              shoes_canvas *canvas, shoes_place *p2) {
    PLACE_COORDS();
    gtk_widget_set_size_request(ref, p2->iw, p2->ih);
    gtk_fixed_put(GTK_FIXED(canvas->slot->oscanvas), ref, p2->ix + p2->dx, p2->iy + p2->dy);
    gtk_widget_show_all(ref);
}

void shoes_native_control_repaint(SHOES_CONTROL_REF ref, shoes_place *p1,
                             shoes_canvas *canvas, shoes_place *p2) {
    p2->iy -= canvas->slot->scrolly;
    if (CHANGED_COORDS()) {
        PLACE_COORDS();
        gtk_fixed_move(GTK_FIXED(canvas->slot->oscanvas),
                       ref, p2->ix + p2->dx, p2->iy + p2->dy);
        gtk_widget_set_size_request(ref, p2->iw, p2->ih);
    }
    p2->iy += canvas->slot->scrolly;
}

void shoes_native_control_focus(SHOES_CONTROL_REF ref) {
    if (gtk_widget_get_can_focus(ref)) gtk_widget_grab_focus(ref);
}

void shoes_native_control_state(SHOES_CONTROL_REF ref, gboolean sensitive, gboolean setting) {
    gtk_widget_set_sensitive(ref, sensitive);
    if (GTK_IS_EDITABLE(ref)) {
        gtk_editable_set_editable(GTK_EDITABLE(ref), setting);
    }
    else if (GTK_IS_SCROLLED_WINDOW(ref)) {
        GtkWidget *textview;
        GTK_CHILD(textview, ref);
        gtk_text_view_set_editable(GTK_TEXT_VIEW(textview), setting);
    }
}

void shoes_native_control_remove(SHOES_CONTROL_REF ref, shoes_canvas *canvas) {
    gtk_container_remove(GTK_CONTAINER(canvas->slot->oscanvas), ref);
}

void shoes_native_control_free(SHOES_CONTROL_REF ref) {
    //
    // no need to free gtk widgets, since gtk seems
    // to garbage collect them fine.  and memory
    // addresses often get reused.
    //
}

void shoes_native_control_set_tooltip(SHOES_CONTROL_REF ref, VALUE tooltip) {
    gtk_widget_set_tooltip_text(GTK_WIDGET(ref), RSTRING_PTR(shoes_native_to_s(tooltip)));
}

VALUE shoes_native_control_get_tooltip(SHOES_CONTROL_REF ref) {
    return rb_str_new2(gtk_widget_get_tooltip_text(GTK_WIDGET(ref)));
}

void shoes_native_secrecy(SHOES_CONTROL_REF ref) {
    gtk_entry_set_visibility(GTK_ENTRY(ref), FALSE);
    gtk_entry_set_invisible_char(GTK_ENTRY(ref), SHOES_GTK_INVISIBLE_CHAR);
}

VALUE shoes_native_clipboard_get(shoes_app *app) {
    //GtkClipboard *primary = gtk_clipboard_get(GDK_SELECTION_PRIMARY);
    GtkClipboard *primary = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    if (gtk_clipboard_wait_is_text_available(primary)) {
        gchar *string = gtk_clipboard_wait_for_text(primary);
        return rb_str_new2(string);
    }
    return Qnil;
}

void shoes_native_clipboard_set(shoes_app *app, VALUE string) {
    //GtkClipboard *primary = gtk_clipboard_get(GDK_SELECTION_PRIMARY);
    GtkClipboard *primary = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
    gtk_clipboard_set_text(primary, RSTRING_PTR(string), RSTRING_LEN(string));
}

VALUE shoes_native_to_s(VALUE text) {
    text = rb_funcall(text, s_to_s, 0);
    return text;
}

/* --------------- dialogs -----------*/

#if defined(GTK3)
VALUE shoes_native_window_color(shoes_app *app) {
    GtkStyleContext *style = gtk_widget_get_style_context(GTK_WIDGET(APP_WINDOW(app)));
    GdkRGBA bg;
#ifdef BSD // assumes Gtk 3.22
    gtk_style_context_lookup_color(style, (char *)NULL, &bg);
#else
    gtk_style_context_lookup_color(style, GTK_STATE_NORMAL, &bg);
#endif
    return shoes_color_new((int)(bg.red * 255), (int)(bg.green * 255),
                           (int)(bg.blue * 255), SHOES_COLOR_OPAQUE);
}

VALUE shoes_native_dialog_color(shoes_app *app) {
    GdkRGBA bg;
    GtkStyleContext *style = gtk_widget_get_style_context(GTK_WIDGET(APP_WINDOW(app)));
#ifdef BSD // assumes Gtk 3.22
    gtk_style_context_lookup_color(style, (char *)NULL, &bg);
#else
    gtk_style_context_lookup_color(style, GTK_STATE_NORMAL, &bg);
#endif
    return shoes_color_new((int)(bg.red * 255), (int)(bg.green * 255),
                           (int)(bg.blue * 255), SHOES_COLOR_OPAQUE);
}
#else
VALUE shoes_native_window_color(shoes_app *app) {
    GtkStyle *style = gtk_widget_get_style(GTK_WIDGET(APP_WINDOW(app)));
    GdkColor bg = style->bg[GTK_STATE_NORMAL];
    return shoes_color_new(bg.red / 257, bg.green / 257, bg.blue / 257, SHOES_COLOR_OPAQUE);
}

VALUE shoes_native_dialog_color(shoes_app *app) {
    GtkStyle *style = gtk_widget_get_style(GTK_WIDGET(APP_WINDOW(app)));
    GdkColor bg = style->bg[GTK_STATE_NORMAL];
    return shoes_color_new(bg.red / 257, bg.green / 257, bg.blue / 257, SHOES_COLOR_OPAQUE);
}
#endif

VALUE shoes_dialog_alert(int argc, VALUE *argv, VALUE self) {
    GTK_APP_VAR(app);
    //char atitle[50]; // bug432 
    char atitle[192];
    g_sprintf(atitle, "%s says", title_app);
    rb_arg_list args;
    rb_parse_args(argc, argv, "S|h", &args);
    char *msg = RSTRING_PTR(shoes_native_to_s(args.a[0]));

    gchar *format_string = "<span size='larger'>%s</span>\n\n%s";
    if (argc == 2) {
        if (RTEST(ATTR(args.a[1], title))) {
            VALUE tmpstr = ATTR(args.a[1], title);
            strcpy(atitle,RSTRING_PTR(shoes_native_to_s(tmpstr)));
        } else {
            g_stpcpy(atitle," ");
        }
    }

    GtkWidget *dialog = gtk_message_dialog_new_with_markup(
                            window_app, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK,
                            format_string, atitle, msg );

    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(GTK_WIDGET(dialog)),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
    gtk_dialog_run(GTK_DIALOG(dialog));

    gtk_widget_destroy(GTK_WIDGET(dialog));
    return Qnil;
}

VALUE shoes_dialog_ask(int argc, VALUE *argv, VALUE self) {
    char atitle[192];
    GTK_APP_VAR(app);

    VALUE answer = Qnil;
    rb_arg_list args;
    rb_parse_args(argc, argv, "S|h", &args);

    switch(argc) {
        case 1:
            sprintf(atitle, "%s asks", title_app);
            break;
        case 2:
            if (RTEST(ATTR(args.a[1], title))) {
                VALUE tmpstr = ATTR(args.a[1], title);
                strcpy(atitle, RSTRING_PTR(shoes_native_to_s(tmpstr)));
            } else {
                g_stpcpy(atitle," ");
            }
            break;
    }

    GtkWidget *dialog = gtk_dialog_new_with_buttons(atitle, window_app, GTK_DIALOG_MODAL,
                        _("_Cancel"), GTK_RESPONSE_CANCEL, _("_OK"), GTK_RESPONSE_OK, NULL);

    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(GTK_WIDGET(dialog)),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
    gtk_container_set_border_width(GTK_CONTAINER(dialog), 6);
    gtk_container_set_border_width(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), 6);
    GtkWidget *question = gtk_label_new(RSTRING_PTR(shoes_native_to_s(args.a[0])));
    // TODO: is this really needed?
    if (gtk_get_minor_version() < 14){
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
     gtk_misc_set_alignment(GTK_MISC(question), 0, 0);
#pragma GCC diagnostic pop
    }
    GtkWidget *_answer = gtk_entry_new();
    if (RTEST(ATTR(args.a[1], secret))) shoes_native_secrecy(_answer);
    gtk_box_pack_start(GTK_BOX(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), question, FALSE, FALSE, 3);
    gtk_box_pack_start(GTK_BOX(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), _answer, FALSE, TRUE, 3);

    gtk_widget_show_all(dialog);
    gint result = gtk_dialog_run(GTK_DIALOG(dialog));
    if (result == GTK_RESPONSE_OK) {
        const gchar *txt = gtk_entry_get_text(GTK_ENTRY(_answer));
        answer = rb_str_new2(txt);
    }
    gtk_widget_destroy(dialog);
    return answer;
}


VALUE shoes_dialog_confirm(int argc, VALUE *argv, VALUE self) {
    VALUE answer = Qfalse;
    char atitle[192];
    GTK_APP_VAR(app);
    //char *apptitle = RSTRING_PTR(app->title);
    rb_arg_list args;
    rb_parse_args(argc, argv, "S|h", &args);
    VALUE quiz = shoes_native_to_s(args.a[0]);

    switch(argc) {
        case 1:
            sprintf(atitle, "%s asks", title_app);
            break;
        case 2:
            if (RTEST(ATTR(args.a[1], title))) {
                VALUE tmpstr = ATTR(args.a[1], title);
                strcpy(atitle, RSTRING_PTR(shoes_native_to_s(tmpstr)));
            } else {
                g_stpcpy(atitle," ");
            }
            break;
    }

    GtkWidget *dialog = gtk_dialog_new_with_buttons(atitle, window_app, GTK_DIALOG_MODAL,
                        _("_Cancel"), GTK_RESPONSE_CANCEL, _("_OK"), GTK_RESPONSE_OK, NULL);
    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(dialog),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
    gtk_container_set_border_width(GTK_CONTAINER(dialog), 6);
    gtk_container_set_border_width(GTK_CONTAINER(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), 6);

    GtkWidget *question = gtk_label_new(RSTRING_PTR(quiz));
    // TODO is misc really needed?
    if (gtk_get_minor_version() < 14){
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
     gtk_misc_set_alignment(GTK_MISC(question), 0, 0);
#pragma GCC diagnostic pop
    }
    gtk_box_pack_start(GTK_BOX(gtk_dialog_get_content_area(GTK_DIALOG(dialog))), question, FALSE, FALSE, 3);

    gtk_widget_show_all(dialog);
    gint result = gtk_dialog_run(GTK_DIALOG(dialog));
    if (result == GTK_RESPONSE_OK)
        answer = Qtrue;
    gtk_widget_destroy(dialog);
    return answer;

}

VALUE shoes_dialog_color(VALUE self, VALUE title) {
    VALUE color = Qnil;
    GTK_APP_VAR(app);
    title = shoes_native_to_s(title);
    GtkWidget *dialog = gtk_color_chooser_dialog_new(RSTRING_PTR(title), NULL);

    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(dialog),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
    gint result = gtk_dialog_run(GTK_DIALOG(dialog));
    if (result == GTK_RESPONSE_OK) {
        GdkRGBA _color;
        gtk_color_chooser_get_rgba((GtkColorChooser *)dialog, &_color);
        color = shoes_color_new((int)(_color.red*255), (int)(_color.green*255),
                                (int)(_color.blue*255), (int)(_color.alpha*255));
    }

    gtk_widget_destroy(dialog);
    return color;
}

VALUE shoes_dialog_chooser(VALUE self, char *title, GtkFileChooserAction act, const gchar *button, VALUE attr) {
    VALUE path = Qnil;
#if 0
  GTK_APP_VAR(app);
#else
  //VALUE clsv = rb_funcall2(self, rb_intern("inspect"), 0, Qnil);
  //char *clsname = RSTRING_PTR(clsv);
  //printf("self is %s - > ", clsname);
  char * title_app = "Shoes"; 
  GtkWindow *window_app = NULL; 
  shoes_app *app = NULL; 
  if ( rb_obj_is_kind_of(self,cApp)) {
      // Normal 
      Data_Get_Struct(self, shoes_app, app);
      title_app = RSTRING_PTR(app->title); 
      window_app = APP_WINDOW(app);
  } else {
    // Is it Shoes splash? 
    if (RARRAY_LEN(shoes_world->apps) > 0) { 
      VALUE actual_app = rb_ary_entry(shoes_world->apps, 0);
      Data_Get_Struct(actual_app, shoes_app, app); 
      title_app = RSTRING_PTR(app->title); 
      window_app = APP_WINDOW(app);
    } else {
      // outside an app and not splash - no window. Gtk complains but runs. 
      /*
      VALUE actual_app = rb_funcall2(self, rb_intern("app"), 0, NULL); // this creates a window
      Data_Get_Struct(actual_app, shoes_app, app); 
      title_app = RSTRING_PTR(app->title); 
      window_app = APP_WINDOW(app);
      */
    }
  }
#endif
    if (!NIL_P(attr) && !NIL_P(shoes_hash_get(attr, rb_intern("title"))))
        title = strdup(RSTRING_PTR(shoes_hash_get(attr, rb_intern("title"))));
    GtkWidget *dialog = gtk_file_chooser_dialog_new(title, window_app, act,
                        _("_Cancel"), GTK_RESPONSE_CANCEL, button, GTK_RESPONSE_ACCEPT, NULL);
    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(dialog),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }
    if (act == GTK_FILE_CHOOSER_ACTION_SAVE)
        gtk_file_chooser_set_do_overwrite_confirmation(GTK_FILE_CHOOSER(dialog), TRUE);
    if(RTEST(shoes_hash_get(attr, rb_intern("save"))))
        gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog),
                                          RSTRING_PTR(shoes_hash_get(attr, rb_intern("save"))));
    if(RTEST(shoes_hash_get(attr, rb_intern("types"))) && TYPE(shoes_hash_get(attr, rb_intern("types"))) == T_HASH) {
        VALUE hsh = shoes_hash_get(attr, rb_intern("types"));
        VALUE keys = rb_funcall(hsh, s_keys, 0);
        int i;
        for(i = 0; i < RARRAY_LEN(keys); i++) {
            VALUE key = rb_ary_entry(keys, i);
            VALUE val = rb_hash_aref(hsh, key);
            GtkFileFilter *ff = gtk_file_filter_new();
            gtk_file_filter_set_name(ff, RSTRING_PTR(key));
            gtk_file_filter_add_pattern(ff, RSTRING_PTR(val));
            gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), ff);
        }
    }
    gint result = gtk_dialog_run(GTK_DIALOG(dialog));
    if (result == GTK_RESPONSE_ACCEPT) {
        char *filename;
        filename = gtk_file_chooser_get_filename (GTK_FILE_CHOOSER (dialog));
        path = rb_str_new2(filename);
    }
    if (!NIL_P(attr) && !NIL_P(shoes_hash_get(attr, rb_intern("title"))))
        SHOE_FREE(title);
    gtk_widget_destroy(dialog);
    return path;
}

VALUE shoes_dialog_open(int argc, VALUE *argv, VALUE self) {
    rb_arg_list args;
#if 0
    VALUE attr = Qnil;
    char *title;
    switch (rb_parse_args(argc, argv, "|h", &args)) {
        case 0:
            title = strdup("Open file...");
            break;
        case 1:
            attr = args.a[0];
            title = strdup(RSTRING_PTR(shoes_hash_get(attr, rb_intern("title"))));
            break;
    }
    shoes_dialog_chooser(self, title, GTK_FILE_CHOOSER_ACTION_OPEN,
                         _("_Open"), args.a[0]);
    free(title);
    return;
#else
    rb_parse_args(argc, argv, "|h", &args);
    return shoes_dialog_chooser(self, "Open file...", GTK_FILE_CHOOSER_ACTION_OPEN,
                                _("_Open"), args.a[0]);
#endif
}

VALUE shoes_dialog_save(int argc, VALUE *argv, VALUE self) {
    rb_arg_list args;
    rb_parse_args(argc, argv, "|h", &args);
    return shoes_dialog_chooser(self, "Save file...", GTK_FILE_CHOOSER_ACTION_SAVE,
                                _("_Save"), args.a[0]);
}

VALUE shoes_dialog_open_folder(int argc, VALUE *argv, VALUE self) {
    rb_arg_list args;
    rb_parse_args(argc, argv, "|h", &args);
    return shoes_dialog_chooser(self, "Open folder...", GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
                                _("_Open"), args.a[0]);
}

VALUE shoes_dialog_save_folder(int argc, VALUE *argv, VALUE self) {
    rb_arg_list args;
    rb_parse_args(argc, argv, "|h", &args);
    return shoes_dialog_chooser(self, "Save folder...", GTK_FILE_CHOOSER_ACTION_CREATE_FOLDER,
                                _("_Save"), args.a[0]);
}


#ifdef SHOES_GTK_WIN32
// hat tip: https://justcheckingonall.wordpress.com/2008/08/29/console-window-win32-app/
#include <stdio.h>
#include <io.h>
#include <fcntl.h>


// called from main.c(skel) on Windows - works fine
static FILE* shoes_console_out = NULL;
static FILE* shoes_console_in = NULL;

int shoes_win32_console() {

    if (AllocConsole() == 0) {
        // cshoes.exe can get here
        printf("Already have console\n");
        return 0;
    }

    HANDLE handle_out = GetStdHandle(STD_OUTPUT_HANDLE);
    int hCrt = _open_osfhandle((long) handle_out, _O_TEXT);
    FILE* hf_out = _fdopen(hCrt, "w");
    setvbuf(hf_out, NULL, _IONBF, 1);
    *stdout = *hf_out;
    HANDLE handle_in = GetStdHandle(STD_INPUT_HANDLE);
    hCrt = _open_osfhandle((long) handle_in, _O_TEXT);
    FILE* hf_in = _fdopen(hCrt, "r");
    setvbuf(hf_in, NULL, _IONBF, 128);
    *stdin = *hf_in;

    //* stash handles
    shoes_console_out = hf_out;
    shoes_console_in = hf_in;
    return 1;
}

// Called by Shoes after ruby/gtk/shoes is initialized and running
int shoes_native_terminal() {
    // has a console been setup by --console flag?
    if (shoes_console_out == NULL) {
        if (shoes_win32_console() == 0) { // cshoes.exe can do this
            return 1;
        }
    }
    // convert the (cached) FILE * for what ruby wants for fd[0], [1]...
    if (dup2(_fileno(shoes_console_out), 1) == -1) {
        printf("failed dup2 of stdout\n");
    }
    if (dup2(_fileno(shoes_console_out), 2) == -1) {
        printf("failed dup2 of stderr\n");
    }
    if (dup2(_fileno(shoes_console_in), 0) == -1) {
        printf("failed dup2 of stdin\n");
    }
    printf("created win32 console\n");
    return 1;
}

// For bug #428 
int shoes_win10_gtk3_22_check() {
    if (gtk_get_minor_version() < 22)
      return 0;
    // borrowed from
    // https://stackoverflow.com/questions/32115255/c-how-to-detect-windows-10
    int ret = 0;
    NTSTATUS(WINAPI *RtlGetVersion)(LPOSVERSIONINFOEXW);
    OSVERSIONINFOEXW osInfo;

    *(FARPROC*)&RtlGetVersion = GetProcAddress(GetModuleHandleA("ntdll"), "RtlGetVersion");

    if (NULL != RtlGetVersion)
    {
        osInfo.dwOSVersionInfoSize = sizeof(osInfo);
        RtlGetVersion(&osInfo);
        ret = osInfo.dwMajorVersion;
    }
    //printf("windows version %i\n", ret); // win 7 returns '6' go figure
    return ret == 10;
}
#else
/*
int shoes_native_console(char *app_path)
{
  //printf("init gtk console\n");
  shoes_native_app_console(app_path);
  printf("gtk\010k\t console \t\tcreated\n"); //test \b \t in string
  return 1;
}
*/
#endif

/*
 *  ------- monitor handling --------
 *  As usual, gtk 3.22 'fixes' things with deprecations. 
 * 
 *  Currrently using pre 3.22 API.
 *    Screen width is the sum of all monitors. Height is the max of all 
 *    monitors. Do not address monitors just set x. 
*/
int shoes_native_monitor_default() {
  GdkScreen *screen;
  GdkDisplay *display;
  display = gdk_display_get_default();
  screen = gdk_display_get_default_screen(display);
  int mon;
  mon = gdk_screen_get_primary_monitor(screen);
  return mon;
}

void shoes_native_monitor_geometry(int idx, shoes_monitor_t *geo) {

  GdkScreen *screen;
  screen = gdk_screen_get_default();
  GdkRectangle r;
  // workarea approximates visibleFrame on OSX
  //gdk_screen_get_monitor_geometry(screen, idx,  &r);
  gdk_screen_get_monitor_workarea(screen, idx, &r);
  geo->x = r.x;
  geo->y = r.y;
  geo->width = r.width;
  geo->height = r.height;
}

int shoes_native_monitor_count() {
  GdkScreen *screen;
  screen = gdk_screen_get_default();
  int cnt = 0;
  cnt = gdk_screen_get_n_monitors(screen);
  return cnt;
}

// Sets/moves the window onto monitor 
void shoes_native_monitor_set(shoes_app *app) {
  GtkWindow *window = (GtkWindow *)app->os.window;
  GdkDisplay *display;
  GdkScreen *screen;
  screen = gdk_screen_get_default();  
  display = gdk_screen_get_display(screen);
  // sanity checks
  int cnt = 0;
  cnt = gdk_screen_get_n_monitors(screen);
  int realmon; 
  if (app->monitor < cnt && app->monitor >= 0)
    realmon = app->monitor;
  else {
    realmon = 0;
  }
  /*
  fprintf(stderr, "Screen w: %d x h: %d\n", gdk_screen_get_width(screen),
      gdk_screen_get_height(screen));
  fprintf(stderr, "Switch to monitor %d of %d\n", realmon, cnt);
  */ 
  GdkRectangle r;
  gdk_screen_get_monitor_geometry(screen, realmon,  &r);
  gtk_window_move(window, app->x + r.x, app->y);
  // TODO: do a better job of positioning. Worth the effort?
}

// returns the Shoes monitor number that the window is on
int shoes_native_monitor_get(shoes_app *app) {
  GtkWindow *window = (GtkWindow *)app->os.window;
  GdkDisplay *display;
  GdkScreen *screen;
  screen = gtk_window_get_screen(window);
  // determine which monitor that is. Remember: Gtk screen holds Gtk monitors
  int x, y, cnt, i;
  gtk_window_get_position (window, &x, &y);
  cnt = gdk_screen_get_n_monitors(screen);
  for (i = 0; i < cnt; i++) {
    GdkRectangle r;
    gdk_screen_get_monitor_geometry(screen, i,  &r);
    if ((x >= r.x) && (x <= (r.x +r.width)) && (y >= r.y) && (y <= (r.y +r.height))) {
        return i;
    }
  }
  // should never get here, but if it does:
  return gdk_screen_get_primary_monitor(screen);
}


/*  ------- have_menu == true and sizing ---------- */

// hack for windows (gtk < 3.12) - the 65 below is the taskbar height. Hack!!
#if ! GTK_CHECK_VERSION(3,12,0)
void shoes_gtk_set_max(shoes_app *app) {
  int m = shoes_native_monitor_get(app);
  shoes_monitor_t geo;
  shoes_native_monitor_geometry(m, &geo);
  app->os.maxwidth = geo.width;
  app->os.maxheight = geo.height;
  //fprintf(stderr, "max wid: %d hgh: %d\n", geo.width, geo.height);
}

int shoes_gtk_is_maximized(shoes_app *app, int wid, int hgt) {
  int t = wid >= app->os.maxwidth && hgt >= (app->os.maxheight-65);
  //fprintf(stderr, "check %d for wid: %d, hgt: %d\n", t, wid, hgt);
  return t; 
}
#endif

// called only by **Window** signal handler for *size-allocate*
static void shoes_app_gtk_size_menu(GtkWidget *widget, cairo_t *cr, gpointer data) {
    shoes_app *app = (shoes_app *)data;
    if (widget != app->os.window) {
      fprintf(stderr, "widget != app->os.window\n");
      gtk_window_get_size(GTK_WINDOW(app->os.window),  &app->width, &app->height);
    }
#ifdef SZBUG
    fprintf(stderr,"shoes_app_gtk_size_menu: wid: %d hgt: %d\n", app->width, app->height);
#endif
    app->height -= app->mb_height;
    
    // trigger a resize & paint 
    GtkWidget *wdg = app->slot->oscanvas;

    if (wdg != NULL ) {
       gtk_widget_set_size_request(GTK_WIDGET(wdg), -1, app->height);
    }
    
    shoes_canvas_size(app->canvas, app->width, app->height);
}

/*
 *  Called by **canvas->slot** signal handler for *size-allocate*
 *  We can be called twice - for width then for height
*/
static void shoes_canvas_gtk_size_menu(GtkWidget *widget, GtkAllocation *size, gpointer data) {
    VALUE c = (VALUE)data;
    shoes_canvas *canvas;
    Data_Get_Struct(c, shoes_canvas, canvas);
#ifdef SZBUG
    fprintf(stderr,"shoes_canvas_gtk_size_menu: %d %d %d %d\n", size->x, size->y, size->width, size->height);
#endif
    if (canvas->slot->vscroll) { 
            // && (size->height != canvas->slot->scrollh || size->width != canvas->slot->scrollw)) 
        if (size->height != canvas->slot->scrollh) {
          GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(canvas->slot->vscroll));
          gtk_widget_set_size_request(GTK_WIDGET(canvas->slot->vscroll), -1, size->height);
          
          //gtk_widget_set_size_request(GTK_CONTAINER(widget), canvas->app->width, size->height);
          GtkAllocation alloc;
          gtk_widget_get_allocation(GTK_WIDGET (canvas->slot->vscroll), &alloc);  
#ifdef SZBUG
          fprintf(stderr, "alloc: %d %d %d %d\n\n", alloc.x, alloc.y, alloc.width, alloc.height);
#endif
          gtk_fixed_move(GTK_FIXED(canvas->slot->oscanvas), GTK_WIDGET(canvas->slot->vscroll), size->width - alloc.width, 0);
          gtk_adjustment_set_page_size(adj, size->height);
          gtk_adjustment_set_page_increment(adj, size->height - 32);
  
          if (gtk_adjustment_get_page_size(adj) >= gtk_adjustment_get_upper(adj)) {
              gtk_widget_hide(canvas->slot->vscroll);
          }
          else {
              gtk_widget_show(canvas->slot->vscroll);
          }
          canvas->slot->scrollh = size->height;
      } else if (size->width != canvas->slot->scrollw) {
          canvas->slot->scrollw = size->width;
      }
    }
}


/* TODO: sort of fixes bug #349 depends on gtk 3.12 or higher (Boo Windows)
 * seems like overkill or incomplete - it gets called a lot. 
*/
gboolean shoes_app_gtk_configure_menu(GtkWidget *widget, GdkEvent *evt, gpointer data) {
  shoes_app *app = (shoes_app *)data;
  if (widget == app->os.window) {  // GtkWindow
    gtk_window_resize(GTK_WINDOW(widget), evt->configure.width, evt->configure.height);
    shoes_canvas *canvas;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);
#if GTK_CHECK_VERSION(3,12,0)
    if (gtk_window_is_maximized(GTK_WINDOW(widget))) {
#else
    if (shoes_gtk_is_maximized(app, evt->configure.width, evt->configure.height)) {
#endif
    //if (canvas->slot->vscroll && evt->configure.height != app->height) { 
          GtkAdjustment *adj = gtk_range_get_adjustment(GTK_RANGE(canvas->slot->vscroll));
          gtk_widget_set_size_request(GTK_WIDGET(canvas->slot->vscroll), -1, evt->configure.height);
          
          GtkAllocation alloc;
          gtk_widget_get_allocation(GTK_WIDGET(canvas->slot->vscroll), &alloc);  
#ifdef SZBUG
          fprintf(stderr, "shoes_app_gtk_configure_menu %d, %d, %d, %d\n", 
              evt->configure.x, evt->configure.y, evt->configure.width, evt->configure.height);
          fprintf(stderr, "cfg alloc: %d %d %d %d\n\n", alloc.x, alloc.y, alloc.width, alloc.height);
#endif
          gtk_fixed_move(GTK_FIXED(canvas->slot->oscanvas), GTK_WIDGET(canvas->slot->vscroll), evt->configure.width - alloc.width, 0);
          gtk_adjustment_set_page_size(adj, evt->configure.height);
          gtk_adjustment_set_page_increment(adj, evt->configure.height - 32);
  
          if (gtk_adjustment_get_page_size(adj) >= gtk_adjustment_get_upper(adj))
              gtk_widget_hide(canvas->slot->vscroll);
          else {
              gtk_widget_show(canvas->slot->vscroll);
          }
      }
  }
  app->width = evt->configure.width;
  app->height = evt->configure.height;

  return FALSE;
}


void shoes_slot_init_menu(VALUE c, SHOES_SLOT_OS *parent, int x, int y, int width, int height, int scrolls, int toplevel) {
  shoes_canvas *canvas;
  SHOES_SLOT_OS *slot;
  Data_Get_Struct(c, shoes_canvas, canvas);
  
  slot = shoes_slot_alloc(canvas, parent, toplevel);
  
  /* Subclassing GtkFixed so we can override gtk3 size management which creates
     problems with slot height being always tied to inside widgets cumulative heights
     creating heights overflow with no scrollbar !
  */
  if (toplevel) {
      slot->oscanvas = canvas->app->os.shoes_window; // created in app_open
  }
  else {
      slot->oscanvas = gtkfixed_alt_new(width, height);
  }
#ifdef SZBUG
  fprintf(stderr,"shoes_slot_init_menu toplevel: %d, slot->oscanvas %lx\n", toplevel, (unsigned long)slot->oscanvas); 
#endif
  g_signal_connect(G_OBJECT(slot->oscanvas), "draw",
                   G_CALLBACK(shoes_canvas_gtk_paint), (gpointer)c);
  
  g_signal_connect(G_OBJECT(slot->oscanvas), "size-allocate",
                   G_CALLBACK(shoes_canvas_gtk_size_menu), (gpointer)c);
  INFO("shoes_slot_init(%lu)\n", c);
  
  if (toplevel) {
    //gtk_container_add(GTK_CONTAINER(parent->oscanvas), slot->oscanvas);
  } else {
    gtk_fixed_put(GTK_FIXED(parent->oscanvas), GTK_WIDGET(slot->oscanvas), x, y);
  }
  slot->scrollh = slot->scrollw = 0;
  slot->vscroll = NULL;
  if (scrolls) {
    slot->vscroll = gtk_scrollbar_new(GTK_ORIENTATION_VERTICAL,NULL);
    GtkAdjustment *adj;
    adj = gtk_range_get_adjustment(GTK_RANGE(slot->vscroll));
    gtk_adjustment_set_step_increment(adj, 16);
    gtk_adjustment_set_page_increment(adj, height - 32);
    slot->drawevent = NULL;

    g_signal_connect(G_OBJECT(slot->vscroll), "value-changed",
                     G_CALLBACK(shoes_canvas_gtk_scroll), (gpointer)c);
   
    gtk_fixed_put(GTK_FIXED(slot->oscanvas), GTK_WIDGET(slot->vscroll), -100, -100);

    gtk_widget_set_size_request(GTK_WIDGET(slot->oscanvas), width, height);
    //gtk_widget_set_size_request(slot->oscanvas, canvas->app->minwidth, canvas->app->minheight);

    if (!toplevel) 
      ATTRSET(canvas->attr, wheel, scrolls);
  }
  
  if (toplevel)
    shoes_canvas_size(c, width, height);
  else {
    gtk_widget_show_all(GTK_WIDGET(slot->oscanvas));
    canvas->width = 100;
    canvas->height = 100;
  }
}

/*
 *  All apps windows can have a menubur and then the old shoes space below. 
 *  it's optional and the default is no menu for backwards compatibilty
 *  That causes some pixel tweaking and redundency. 
 */
 
shoes_code shoes_native_app_open_menu(shoes_app *app, char *path, int dialog, shoes_settings *st) {
#if 0 //!defined(SHOES_GTK_WIN32)
    char icon_path[SHOES_BUFSIZE];
    sprintf(icon_path, "%s/static/app-icon.png", shoes_world->path);
    gtk_window_set_default_icon_from_file(icon_path, NULL);
#endif
    GtkWidget *window;       // Root window 
    shoes_app_gtk *gk = &app->os; //lexical - typing shortcut

    char icon_path[SHOES_BUFSIZE];

    if (st->icon_path == Qnil) {
        sprintf(icon_path, "%s/static/app-icon.png", shoes_world->path);
    }
    else {
      char *ip = RSTRING_PTR(st->icon_path);
      if (*ip == '/' || ip[1] ==':')  
        strcpy(icon_path, ip);
      else
       sprintf(icon_path, "%s/%s", shoes_world->path, ip);
    }

    gtk_window_set_default_icon_from_file(icon_path, NULL);

    GtkWidget *vbox;         // contents of root window
    GtkWidget *menubar;      // top of vbox
    GtkWidget *shoes_window; // bottom of vbox where shoes does its thing.
    
    menubar = gtk_menu_bar_new();
    gk->menubar = menubar;
#if 0
    // don't do this if gtk_init() is used.
    window = gtk_application_window_new(shoes_GtkApp);
#else
    window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
#endif
    // theme the window
    if (shoes_css_provider != NULL) {
      gtk_style_context_add_provider(gtk_widget_get_style_context(window),
          GTK_STYLE_PROVIDER(shoes_css_provider),
          GTK_STYLE_PROVIDER_PRIORITY_USER);
    }

    vbox =  gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(vbox));
    gtk_box_pack_start(GTK_BOX(vbox), GTK_WIDGET(menubar), FALSE, FALSE, 0);
    // Gtk Container of the fixed variety. Note the alt version!!
    shoes_window = gtkfixed_alt_new(app->width, app->height); 
    gtk_box_pack_start(GTK_BOX(vbox), GTK_WIDGET(shoes_window), FALSE, FALSE, 0);
    
    gk->window = window;
    gk->vlayout = vbox;
    gk->shoes_window = shoes_window;
    app->slot->oscanvas = shoes_window;
#ifdef SZBUG
    fprintf(stderr,"shoes_native_app_open slot->canvas %lx\n", (unsigned long)app->slot->oscanvas);
#endif
    //app->mb_height = 26;  // TODO adhoc (a guess)

    // now we can add the default Shoes menus
    VALUE mbv = shoes_native_menubar_setup(app, menubar);
    shoes_native_build_menus(app, mbv);
    app->menubar = mbv;
         
    gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
   // commit https://github.com/shoes/shoes/commit/4e7982ddcc8713298b6959804dab8d20111c0038
    if (!app->resizable) {
        gtk_window_resize(GTK_WINDOW(window), app->width, app->height + app->mb_height);
        gtk_window_set_resizable(GTK_WINDOW(window), FALSE);
    } else if (app->minwidth < app->width || app->minheight < app->height + app->mb_height) {
        GdkGeometry hints;
        hints.min_width = max(app->minwidth, 100);
        hints.min_height = max(app->minheight + app->mb_height, 100);

#ifdef SZBUG
        fprintf(stderr,"resize hints: %d, %d\n", hints.min_width, hints.min_height);
#endif

        gtk_window_set_geometry_hints(GTK_WINDOW(window), NULL, &hints, GDK_HINT_MIN_SIZE);
        //gtk_window_set_resizable(GTK_WINDOW(window), TRUE); // no help with szbug
    }

    gtk_window_set_default_size(GTK_WINDOW(window), app->width, app->height + app->mb_height);

    gtk_window_get_position(GTK_WINDOW(window), &app->x, &app->y);
    // get memubar height
    GtkRequisition reqmin, reqnat;
    gtk_widget_get_preferred_size(menubar, &reqmin, &reqnat);
    app->mb_height = reqmin.height;

    g_signal_connect(G_OBJECT(window), "size-allocate",
                     G_CALLBACK(shoes_app_gtk_size_menu), app);
    g_signal_connect(G_OBJECT(window), "motion-notify-event",
                     G_CALLBACK(shoes_app_gtk_motion), app);
    g_signal_connect(G_OBJECT(window), "button-press-event",
                     G_CALLBACK(shoes_app_gtk_button), app);
    g_signal_connect(G_OBJECT(window), "button-release-event",
                     G_CALLBACK(shoes_app_gtk_button), app);
    g_signal_connect(G_OBJECT(window), "scroll-event",
                     G_CALLBACK(shoes_app_gtk_wheel), app);
    g_signal_connect(G_OBJECT(window), "key-press-event",
                     G_CALLBACK(shoes_app_gtk_keypress), app);
    g_signal_connect(G_OBJECT(window), "key-release-event",
                     G_CALLBACK(shoes_app_gtk_keypress), app);
    g_signal_connect(G_OBJECT(window), "delete-event",
                     G_CALLBACK(shoes_app_gtk_quit), app);
    g_signal_connect(G_OBJECT(window), "configure-event",   // bug #349
                     G_CALLBACK(shoes_app_gtk_configure_menu), app);
       
    if (app->fullscreen) {
        shoes_native_app_fullscreen(app, 1);
    }

    gtk_window_set_decorated(GTK_WINDOW(window), app->decorated);
#if GTK_CHECK_VERSION(3,8,0)
    gtk_widget_set_opacity(GTK_WIDGET(window), app->opacity);
#endif
    // ORIG: gtk_widget_set_events(window, GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);
    gtk_widget_add_events(window, GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK);


    // If the user asked for a specific Screen (Monitor) for the Window
    if (app->monitor >= 0) {
      shoes_native_monitor_set(app);
    }
#if ! GTK_CHECK_VERSION(3,12,0)
    shoes_gtk_set_max(app);
#endif
    return SHOES_OK;
}

