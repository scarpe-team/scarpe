//
// shoes/app.c
// Abstract windowing for GTK, Quartz (OSX) and Win32.
//
#include <glib.h>
#include "shoes/app.h"
#include "shoes/internal.h"
#include "shoes/ruby.h"
#include "shoes/canvas.h"
#include "shoes/world.h"
#include "shoes/types/settings.h"
#include "shoes/native/native.h"
#include "shoes/types/text.h"
#include "shoes/types/text_link.h"
#include "shoes/types/textblock.h"
#include "shoes/types/native.h"
#include "shoes/types/event.h"

// Global var:
int shoes_app_serial_num = 0;

static void shoes_app_mark(shoes_app *app) {
    shoes_native_slot_mark(app->slot);
    rb_gc_mark_maybe(app->title);
    rb_gc_mark_maybe(app->location);
    rb_gc_mark_maybe(app->canvas);
    rb_gc_mark_maybe(app->keypresses);
    rb_gc_mark_maybe(app->nestslot);
    rb_gc_mark_maybe(app->nesting);
    rb_gc_mark_maybe(app->extras);
    rb_gc_mark_maybe(app->styles);
    rb_gc_mark_maybe(app->groups);
    rb_gc_mark_maybe(app->owner);
    rb_gc_mark_maybe(app->menubar);
}

static void shoes_app_free(shoes_app *app) {
    SHOE_FREE(app->slot);
    cairo_destroy(app->scratch);
    RUBY_CRITICAL(free(app));
}

VALUE shoes_app_alloc(VALUE klass) {
    shoes_app *app = SHOE_ALLOC(shoes_app);
    SHOE_MEMZERO(app, shoes_app, 1);
    app->slot = SHOE_ALLOC(SHOES_SLOT_OS);
    SHOE_MEMZERO(app->slot, SHOES_SLOT_OS, 1);
    app->slot->owner = app;
    app->started = FALSE;
    app->owner = Qnil;
    app->location = Qnil;
    app->canvas = shoes_canvas_new(cShoes, app);
    app->keypresses = rb_hash_new();
    app->nestslot = Qnil;
    app->nesting = rb_ary_new();
    app->extras = rb_ary_new();
    app->groups = Qnil;
    app->styles = Qnil;
    app->title = Qnil;
    app->x = 0;
    app->y = 0;
    app->width = SHOES_APP_WIDTH;
    app->height = SHOES_APP_HEIGHT;
    app->minwidth = 0;
    app->minheight = 0;
    app->fullscreen = FALSE;
    app->resizable = TRUE;
    app->decorated = TRUE;
    app->opacity = 1.0;
    app->cursor = s_arrow_cursor;
    app->use_event_handler = 0;
    app->have_menu = 0;
    app->menubar = rb_ary_new();
    app->mb_height = 0;
    app->monitor = -1;
    app->id = 0;
    app->scratch = cairo_create(cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1, 1));
    app->self = Data_Wrap_Struct(klass, shoes_app_mark, shoes_app_free, app);
    rb_extend_object(app->self, cTypes);
    return app->self;
}

VALUE shoes_app_new(VALUE klass) {
    VALUE app = shoes_app_alloc(klass);
    rb_ary_push(shoes_world->apps, app);
    return app;
}

VALUE shoes_apps_get(VALUE self) {
    return rb_ary_dup(shoes_world->apps);
}

static void shoes_app_clear(shoes_app *app) {
    shoes_ele_remove_all(app->extras);
//  shoes_canvas *canvas;
//  Data_Get_Struct(app->canvas, shoes_canvas, canvas);
//  shoes_extras_remove_all(canvas);
    shoes_canvas_clear(app->canvas);
    app->nestslot = Qnil;
    app->groups = Qnil;
}

//
// When a window is finished, call this to delete it from the master
// list.  Returns 1 if all windows are gone.
//
int shoes_app_remove(shoes_app *app) {
    // gives a chance to cleanup before quit
    shoes_canvas_send_finish(app->canvas);

    shoes_app_clear(app);
    rb_ary_delete(shoes_world->apps, app->self);
    return (RARRAY_LEN(shoes_world->apps) == 0);
}

shoes_code shoes_app_resize(shoes_app *app, int width, int height) {
    app->width = width;
    app->height = height;
    shoes_native_app_resize_window(app);
    return SHOES_OK;
}

VALUE shoes_app_window(int argc, VALUE *argv, VALUE self, VALUE owner) {
    rb_arg_list args;
    VALUE attr = Qnil;
    VALUE app = shoes_app_new(self == cDialog ? cDialog : cApp);
    shoes_app *app_t;
    char *url = "/";
    Data_Get_Struct(app, shoes_app, app_t);

    switch (rb_parse_args(argc, argv, "h,s|h,", &args)) {
        case 1:
            attr = args.a[0];
            break;

        case 2:
            url = RSTRING_PTR(args.a[0]);
            attr = args.a[1];
            break;
    }

    if (rb_block_given_p()) rb_iv_set(app, "@main_app", rb_block_proc());
    app_t->owner = owner;
#ifndef MTITLE
    app_t->title = ATTR(attr, title);
#else
    if (RTEST(ATTR(attr,title)))
      app_t->title = ATTR(attr, title);
    else {
      shoes_settings *st;
      Data_Get_Struct(shoes_world->settings, shoes_settings, st);
      app_t->title = st->app_name;
    }
#endif 
    app_t->fullscreen = RTEST(ATTR(attr, fullscreen));
    app_t->resizable = (ATTR(attr, resizable) != Qfalse);
    app_t->decorated = (ATTR(attr, decorated) != Qfalse);
    app_t->hidden = (ATTR(attr, hidden) == Qtrue);
    
    app_t->mb_height = 0;
    app_t->have_menu = 0;
    if (RTEST(ATTR(attr, menus))) {
      app_t->have_menu = TRUE;
    }
    app_t->menubar = Qnil;
    app_t->id = ++shoes_app_serial_num;
    
    if (RTEST(ATTR(attr, monitor))) {
      app_t->monitor = NUM2INT(ATTR(attr,monitor));
    } 

    if (RTEST(ATTR(attr, opacity)))
        if ((0.0 <= NUM2DBL(ATTR(attr, opacity))) && (1.0 >= NUM2DBL(ATTR(attr, opacity))))
            app_t->opacity = NUM2DBL(ATTR(attr, opacity));

    shoes_app_resize(app_t, ATTR2(int, attr, width, SHOES_APP_WIDTH), ATTR2(int, attr, height, SHOES_APP_HEIGHT));
    if (RTEST(ATTR(attr, minwidth)))
        //app_t->minwidth = (NUM2INT(ATTR(attr, minwidth)) - 1) / 2;
        app_t->minwidth = NUM2INT(ATTR(attr, minwidth));
    if (RTEST(ATTR(attr, minheight)))
        //app_t->minheight = (NUM2INT(ATTR(attr, minheight)) -1) / 2;
        app_t->minheight = NUM2INT(ATTR(attr, minheight));
    shoes_canvas_init(app_t->canvas, app_t->slot, attr, app_t->width, app_t->height);
    if (shoes_world->mainloop)
        shoes_app_open(app_t, url);
    return app;
}

VALUE shoes_app_main(int argc, VALUE *argv, VALUE self) {
    return shoes_app_window(argc, argv, self, Qnil);
}

VALUE shoes_app_slot(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return app_t->nestslot;
}

VALUE shoes_app_get_width(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return INT2NUM(app_t->width);
}

VALUE shoes_app_get_height(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return INT2NUM(app_t->height);
}

VALUE shoes_app_get_window_x_position(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    shoes_native_app_get_window_position(app_t);
    return INT2NUM(app_t->x);
}

VALUE shoes_app_get_window_y_position(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    shoes_native_app_get_window_position(app_t);
    return INT2NUM(app_t->y);
}

VALUE shoes_app_set_window_position(VALUE app, VALUE x, VALUE y) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    
    app_t->x = NUM2INT(x);
    app_t->y = NUM2INT(y);

    shoes_native_app_window_move(app_t, app_t->x, app_t->y);

    return Qtrue;
}

VALUE shoes_app_set_icon(VALUE app, VALUE icon_path) {
    shoes_app *app_t;
    char *path;
    Data_Get_Struct(app, shoes_app, app_t);
    path = RSTRING_PTR(icon_path);
    shoes_settings *st;
    Data_Get_Struct(shoes_world->settings, shoes_settings, st);
    st->icon_path = icon_path;  // Watch out, this could be ABS path
    shoes_native_app_set_icon(app_t, path);
    return Qtrue;
}

VALUE shoes_app_resize_window(VALUE app, VALUE width, VALUE height) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    app_t->width = NUM2INT(width);
    app_t->height = NUM2INT(height);
    shoes_native_app_resize_window(app_t);
    return Qtrue;
}

VALUE shoes_app_get_resizable(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return shoes_native_get_resizable(app_t) ? Qtrue : Qfalse;
}

VALUE shoes_app_set_resizable(VALUE app, VALUE resizable) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);

    shoes_native_set_resizable(app_t, app_t->resizable = RTEST(resizable));

    return resizable;
}

// TODO deprecate this in Ruby
VALUE shoes_app_set_wtitle(VALUE app, VALUE title) {
    shoes_app *app_t;
    char *wtitle;
    Data_Get_Struct(app, shoes_app, app_t);
    app_t->title = title;
    shoes_settings *st;
    Data_Get_Struct(shoes_world->settings, shoes_settings, st);
    st->app_name = title;
    wtitle = RSTRING_PTR(title);
    shoes_native_app_title(app_t, wtitle);
    return Qtrue;
}

VALUE shoes_app_get_title(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return app_t->title;
}

VALUE shoes_app_set_title(VALUE app, VALUE title) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    if (!NIL_P(title)) {
      app_t->title = title;
      // api change 3.3.7: really change the visible title
      shoes_native_app_title(app_t, RSTRING_PTR(title));  
    }
    return app_t->title ;
}

void shoes_app_title(shoes_app *app, VALUE title) {
    char *msg;
    if (!NIL_P(title))
        app->title = title;
    else {
      shoes_settings *st;
      Data_Get_Struct(shoes_world->settings, shoes_settings, st);
      app->title = st->app_name;
    }
    msg = RSTRING_PTR(app->title);
    shoes_native_app_title(app, msg);
}


VALUE shoes_app_get_fullscreen(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return app_t->fullscreen ? Qtrue : Qfalse;
}

VALUE shoes_app_set_fullscreen(VALUE app, VALUE yn) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    shoes_native_app_fullscreen(app_t, app_t->fullscreen = RTEST(yn));
    return yn;
}

VALUE shoes_app_set_opacity(VALUE app, VALUE opacity) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    app_t->opacity = NUM2DBL(opacity);

    if ((0.0 <= app_t->opacity) && (1.0 >= app_t->opacity))
        shoes_native_app_set_opacity(app_t, app_t->opacity);

    return Qtrue;
}

VALUE shoes_app_get_opacity(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return DBL2NUM(shoes_native_app_get_opacity(app_t));
}


VALUE shoes_app_set_decoration(VALUE app, VALUE decorated) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    shoes_native_app_set_decoration(app_t, (decorated != Qfalse));
    return Qtrue;
}

VALUE shoes_app_get_decoration(VALUE app) {
    shoes_app *app_t;
    Data_Get_Struct(app, shoes_app, app_t);
    return (shoes_native_app_get_decoration(app_t) ? Qtrue : Qfalse);
}

VALUE shoes_app_set_cache(VALUE app, VALUE boolv) {
    shoes_cache_setting = (boolv == Qtrue) ? 1 : 0;
    return boolv;
}

VALUE shoes_app_get_cache(VALUE app) {
    return shoes_cache_setting ? Qtrue: Qnil;
}

VALUE shoes_app_clear_cache(VALUE app, VALUE opts) {
  int mem, ext = 0;
  if (opts == ID2SYM(rb_intern("memory")))
    mem = 1;
  if (opts == ID2SYM(rb_intern("eternal")))
    ext = 1;
  if (opts == ID2SYM(rb_intern("all"))) {
    ext = 1;
    mem = 1;
  }
  if (mem) 
    st_clear(shoes_world->image_cache);
  if (ext) {
    // call into shoes/ruby 
    rb_require("shoes/data");
    rb_funcall(rb_const_get(rb_cObject, rb_intern("DATABASE")), rb_intern("delete_cache"), 0);
  }
  return Qtrue;
}

shoes_code shoes_app_start(VALUE allapps, char *uri) {
    int i;
    shoes_code code;
    shoes_app *app;

    for (i = 0; i < RARRAY_LEN(allapps); i++) {
        VALUE appobj2 = rb_ary_entry(allapps, i);
        Data_Get_Struct(appobj2, shoes_app, app);
        if (!app->started) {
            code = shoes_app_open(app, uri);
            app->started = TRUE;
            if (code != SHOES_OK)
                return code;
        }
    }

    return shoes_app_loop();
}

shoes_code shoes_app_open(shoes_app *app, char *path) {
    shoes_code code = SHOES_OK;
    int dialog = (rb_obj_class(app->self) == cDialog);
    shoes_settings *st;
    Data_Get_Struct(shoes_world->settings, shoes_settings, st);
    
    if (st->use_menus == Qtrue) {
      app->have_menu = 1;   
    }
#ifndef SHOES_QUARTZ
    // gtk has two ways to open 
    if (app->have_menu)
      code = shoes_native_app_open_menu(app, path, dialog, st);
    else
#endif
      code = shoes_native_app_open(app, path, dialog, st);
      
    if (code != SHOES_OK)
        return code;
#ifndef MTITTLE
    shoes_app_title(app, app->title);
#else
    shoes_settings *st;
    Data_Get_Struct(shoes_settings_globalv, shoes_settings, st);
    shoes_app_title(app, st->app_name);
#endif
    if (app->slot != NULL)
       shoes_native_slot_reset(app->slot);
#ifndef SHOES_QUARTZ
    if (app->have_menu)
      shoes_slot_init_menu(app->canvas, app->slot, 0, 0, app->width, app->height, TRUE, TRUE);
    else
#endif
      shoes_slot_init(app->canvas, app->slot, 0, 0, app->width, app->height, TRUE, TRUE);

    code = shoes_app_goto(app, path);
    if (code != SHOES_OK)
        return code;

    if (!app->hidden)
        shoes_native_app_show(app);
    return code;
}

shoes_code shoes_app_loop() {
    if (shoes_world->mainloop)
        return SHOES_OK;

    shoes_world->mainloop = TRUE;
    INFO("RUNNING LOOP.\n");
    shoes_native_loop();
    return SHOES_OK;
}

typedef struct {
    shoes_app *app;
    VALUE canvas;
    VALUE block;
    char ieval;
    VALUE args;
} shoes_exec;

#ifndef RUBY_1_8
struct METHOD {
    VALUE oclass;		/* class that holds the method */
    VALUE rklass;		/* class of the receiver */
    VALUE recv;
    ID id, oid;
    void *body; /* NODE *body; */
};
#else
struct METHOD {
    VALUE klass, rklass;
    VALUE recv;
    ID id, oid;
    int safe_level;
    NODE *body;
};
#endif

/*
** no longer used
static VALUE
rb_unbound_get_class(VALUE method)
{
  struct METHOD *data;
  Data_Get_Struct(method, struct METHOD, data);
  return data->rklass;
}
*/

static VALUE shoes_app_run(VALUE rb_exec) {
    shoes_exec *exec = (shoes_exec *)rb_exec;
    rb_ary_push(exec->app->nesting, exec->canvas);
    if (exec->ieval) {
        VALUE obj;
        obj = mfp_instance_eval(exec->app->self, exec->block);
        return obj;
    } else {
        int i;
        VALUE vargs[10];
        for (i = 0; i < RARRAY_LEN(exec->args); i++)
            vargs[i] = rb_ary_entry(exec->args, i);
        return rb_funcall2(exec->block, s_call, (int)RARRAY_LEN(exec->args), vargs);
    }
}

static VALUE shoes_app_exception(VALUE rb_exec, VALUE e) {
    shoes_exec *exec = (shoes_exec *)rb_exec;
    rb_ary_clear(exec->app->nesting);
    shoes_canvas_error(exec->canvas, e);
    return Qnil;
}

shoes_code shoes_app_visit(shoes_app *app, char *path) {
    shoes_exec exec;
    shoes_canvas *canvas;
    VALUE meth;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);

    canvas->slot->scrolly = 0;
    shoes_native_slot_clear(canvas);
    shoes_app_clear(app);
    shoes_app_reset_styles(app);
    meth = rb_funcall(cShoes, s_run, 1, app->location = rb_str_new2(path));

    VALUE app_block = rb_iv_get(app->self, "@main_app");
    if (!NIL_P(app_block))
        rb_ary_store(meth, 0, app_block);
        
    exec.app = app;
    exec.block = rb_ary_entry(meth, 0);
    exec.args = rb_ary_entry(meth, 1);
    if (rb_obj_is_kind_of(exec.block, rb_cUnboundMethod)) {
        // VALUE klass = rb_unbound_get_class(exec.block);
        VALUE klass = rb_ary_entry(meth, 2);
        exec.canvas = app->nestslot = shoes_slot_new(klass, ssNestSlot, app->canvas);
        exec.block = rb_funcall(exec.block, s_bind, 1, exec.canvas);
        exec.ieval = 0;
        rb_ary_push(canvas->contents, exec.canvas);
    } else {
        exec.canvas = app->nestslot = app->canvas;
        exec.ieval = 1;
    }
    
    rb_rescue2(CASTHOOK(shoes_app_run), (VALUE)&exec, CASTHOOK(shoes_app_exception), (VALUE)&exec, rb_cObject, 0);

    rb_ary_clear(exec.app->nesting);
    return SHOES_OK;
}

shoes_code shoes_app_paint(shoes_app *app) {
    shoes_canvas_paint(app->canvas);
    return SHOES_OK;
}

/* ------ Settings --------
 * a script called Shoes.settings - Danger ahead for them
 * 
*/
VALUE shoes_app_settings(VALUE app) {
  return shoes_world->settings;
}


/* ------ GUI events ------ */

/* TODO:  move this debugging code to ruby.c ? */
int shoes_hash_debug_cb (VALUE key, VALUE val, VALUE extra) {
  char *keystr, *valstr = NULL;
  char kbuff[40], vbuff[40];
  // TODO: should be a long switch/case for all TYPE(key)
  switch (TYPE(key)) {
    case T_SYMBOL:
      sprintf(kbuff, ":%s", RSTRING_PTR(rb_sym_to_s(key)));
      keystr = kbuff;
      break;
    case T_STRING:
      keystr = StringValueCStr(key);
      break;
    default:
      keystr = "Unknown";
  }
  // TODO: should be a long switch/case  for all TYPE(val)
  switch (TYPE(val)) {
    case T_FIXNUM:
      sprintf(vbuff,"%i", NUM2INT(val));
      valstr = vbuff;
      break;
    case T_STRING:
      valstr = RSTRING_PTR(val);
      break;
    default:
      valstr = "Unknown";
  }
  fprintf(stderr, "  %s => %s\n", keystr, valstr);
  return ST_CONTINUE;
 }

void shoes_hash_debug(VALUE attr) {
  fprintf(stderr, "Display hash at %i\n", (int)attr);
  if (TYPE(attr) != T_HASH) {
    fprintf(stderr, "hash_debug: Arg is NOT A HASH\n"); 
    return;
  }
  rb_hash_foreach(attr, shoes_hash_debug_cb, Qnil);
}

VALUE shoes_app_set_event_handler(VALUE self, VALUE block) {
    shoes_app *app;
    Data_Get_Struct(self, shoes_app, app);
    shoes_canvas *canvas; 
    Data_Get_Struct(app->canvas, shoes_canvas, canvas); 
    if (rb_obj_is_kind_of(block, rb_cProc)) {
      fprintf(stderr, "set app event handler\n");
      ATTRSET(canvas->attr, event, block);  
      canvas->app->use_event_handler = 1;
      //shoes_hash_debug(canvas->attr);
      return Qtrue;
    } else {
      canvas->app->use_event_handler = 0;
    }
    return Qnil;
}



shoes_code shoes_app_motion(shoes_app *app, int x, int y, int mods) {
    app->mousex = x;
    app->mousey = y;
    VALUE sendevt = Qtrue;
    VALUE modifiers = Qnil;
    if (mods & SHOES_MODIFY_CTRL) {
      if (mods & SHOES_MODIFY_SHIFT) 
        modifiers = rb_utf8_str_new_cstr("control_shift");
      else
        modifiers = rb_utf8_str_new_cstr("control");
    } 
    else if (mods & SHOES_MODIFY_SHIFT) 
      modifiers = rb_utf8_str_new_cstr("shift");
      
    if (app->use_event_handler) {
      VALUE evt = shoes_event_create_event(app, s_motion, 0, x, y, modifiers, Qnil);
      shoes_canvas *canvas;
      Data_Get_Struct(app->canvas, shoes_canvas, canvas);
      VALUE event = ATTR(canvas->attr, event);  
      if (! NIL_P(event)) {
        shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
        shoes_event *tevent;
        Data_Get_Struct(evt, shoes_event, tevent);
        sendevt = shoes_event_contrain_TF(tevent->accept);
      } else {
        fprintf(stderr, "click: don't have event - but should - dump hash\n");
        shoes_hash_debug(canvas->attr);
      }
    }
    if (sendevt == Qtrue)
      shoes_canvas_send_motion(app->canvas, x, y, Qnil, modifiers);
    return SHOES_OK;
}
EXTERN ID s_shift_key, s_control_key;

shoes_code shoes_app_click(shoes_app *app, int button, int x, int y, int mods) {
    app->mouseb = button;
    VALUE sendevt = Qtrue;
    VALUE modifiers = Qnil;
    if (mods & SHOES_MODIFY_CTRL) {
      if (mods & SHOES_MODIFY_SHIFT) 
        modifiers = rb_utf8_str_new_cstr("control_shift");
      else
        modifiers = rb_utf8_str_new_cstr("control");
    } 
    else if (mods & SHOES_MODIFY_SHIFT) 
      modifiers = rb_utf8_str_new_cstr("shift");
      
    if (app->use_event_handler) {
      VALUE evt = shoes_event_create_event(app, s_click, button, x, y, modifiers, Qnil);
      shoes_canvas *canvas;
      Data_Get_Struct(app->canvas, shoes_canvas, canvas);
      VALUE event = ATTR(canvas->attr, event);  
      if (! NIL_P(event)) {
        shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
        shoes_event *tevent;
        Data_Get_Struct(evt, shoes_event, tevent);
        sendevt = shoes_event_contrain_TF(tevent->accept);
      } else {
        fprintf(stderr, "click: don't have event - but should - dump hash\n");
        shoes_hash_debug(canvas->attr);
      }
    }
    if (sendevt == Qtrue)
      shoes_canvas_send_click(app->canvas, button, x, y, modifiers);
    return SHOES_OK;
}

shoes_code shoes_app_release(shoes_app *app, int button, int x, int y, int mods) {
    app->mouseb = 0;
    VALUE modifiers = Qnil;
    VALUE sendevt = Qtrue;
    if (mods & SHOES_MODIFY_CTRL) {
      if (mods & SHOES_MODIFY_SHIFT) 
        modifiers = rb_utf8_str_new_cstr("control_shift");
      else
        modifiers = rb_utf8_str_new_cstr("control");
    } 
    else if (mods & SHOES_MODIFY_SHIFT) 
      modifiers = rb_utf8_str_new_cstr("shift");
      
    if (app->use_event_handler) {
      VALUE evt = shoes_event_create_event(app, s_release, button, x, y, modifiers, Qnil);
      shoes_canvas *canvas;
      Data_Get_Struct(app->canvas, shoes_canvas, canvas);
      VALUE event = ATTR(canvas->attr, event);  
      if (! NIL_P(event)) {
        shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
        shoes_event *tevent;
        Data_Get_Struct(evt, shoes_event, tevent);
        sendevt = shoes_event_contrain_TF(tevent->accept);
      } else {
        fprintf(stderr, "release: doen't have event - but should - dump hash\n");
        shoes_hash_debug(canvas->attr);
      }
    }
    if (sendevt == Qtrue)
      shoes_canvas_send_release(app->canvas, button, x, y, modifiers);
    return SHOES_OK;
}

shoes_code shoes_app_wheel(shoes_app *app, ID dir, int x, int y, int mods) {
    VALUE sendevt = Qtrue;
    VALUE modifiers = Qnil;
    shoes_canvas *canvas;
    Data_Get_Struct(app->canvas, shoes_canvas, canvas);
    if (canvas->slot->vscroll) shoes_canvas_wheel_way(canvas, dir);
    if (mods & SHOES_MODIFY_CTRL) {
      if (mods & SHOES_MODIFY_SHIFT) 
        modifiers = rb_utf8_str_new_cstr("control_shift");
      else
        modifiers = rb_utf8_str_new_cstr("control");
    } 
    else if (mods & SHOES_MODIFY_SHIFT) 
      modifiers = rb_utf8_str_new_cstr("shift");
      
    if (app->use_event_handler) {
      VALUE evt = shoes_event_create_event(app, s_wheel, (dir == s_up), x, y, modifiers, Qnil);
      shoes_canvas *canvas;
      Data_Get_Struct(app->canvas, shoes_canvas, canvas);
      VALUE event = ATTR(canvas->attr, event);  
      if (! NIL_P(event)) {
        shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
        shoes_event *tevent;
        Data_Get_Struct(evt, shoes_event, tevent);
        sendevt = shoes_event_contrain_TF(tevent->accept);
      } else {
        fprintf(stderr, "wheel: doen't have event - but should - dump hash\n");
        shoes_hash_debug(canvas->attr);
      }
    }
    if (sendevt == Qtrue)
        shoes_canvas_send_wheel(app->canvas, dir, x, y, modifiers) ;
    return SHOES_OK;
}

shoes_code shoes_app_keypress(shoes_app *app, VALUE key) {
    VALUE sendevt = Qtrue;
    if (key == symAltSlash)
        rb_eval_string("Shoes.show_log");
    else if (key == symAltQuest)
        rb_eval_string("Shoes.show_manual");
    else if (key == symAltDot)
        rb_eval_string("Shoes.show_selector");
    else if (key == symAltEqual)
        rb_eval_string("Shoes.show_irb");
    else if (key == symAltSemiColon)
        rb_eval_string("Shoes.remote_debug");
    else {
      if (app->use_event_handler) {
        VALUE evt = shoes_event_new_key(cShoesEvent, s_keypress, key);
        shoes_canvas *canvas;
        Data_Get_Struct(app->canvas, shoes_canvas, canvas);
        VALUE event = ATTR(canvas->attr, event);  
        if (! NIL_P(event)) {
          shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
          shoes_event *tevent;
          Data_Get_Struct(evt, shoes_event, tevent);
          sendevt = shoes_event_contrain_TF(tevent->accept);
        } else {
          fprintf(stderr, "keypress: doen't have event - but should - dump hash\n");
          shoes_hash_debug(canvas->attr);
        }
      }
      if (sendevt == Qtrue)
          shoes_canvas_send_keypress(app->canvas, key);
    }
    return SHOES_OK;
}

shoes_code shoes_app_keydown(shoes_app *app, VALUE key) {
  VALUE sendevt = Qtrue;
  if (!RTEST(rb_hash_aref(app->keypresses, key))) {
    rb_hash_aset(app->keypresses, key, Qtrue);
    if (app->use_event_handler) {
      VALUE evt = shoes_event_new_key(cShoesEvent, s_keydown, key);
      shoes_canvas *canvas;
      Data_Get_Struct(app->canvas, shoes_canvas, canvas);
      VALUE event = ATTR(canvas->attr, event);  
      if (! NIL_P(event)) {
        shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
        shoes_event *tevent;
        Data_Get_Struct(evt, shoes_event, tevent);
        sendevt = shoes_event_contrain_TF(tevent->accept);
      } else {
        fprintf(stderr, "keydown: doen't have event - but should - dump hash\n");
        shoes_hash_debug(canvas->attr);
      }
    }
    if (sendevt == Qtrue) {
        shoes_canvas_send_keydown(app->canvas, key);
    }    
  }
  return SHOES_OK;
}

shoes_code shoes_app_keyup(shoes_app *app, VALUE key) {
    VALUE sendevt = Qtrue;
    rb_hash_aset(app->keypresses, key, Qfalse);
    shoes_canvas_send_keyup(app->canvas, key);
    if (app->use_event_handler) {
      VALUE evt = shoes_event_new_key(cShoesEvent, s_keyup, key);
      shoes_canvas *canvas;
      Data_Get_Struct(app->canvas, shoes_canvas, canvas);
      VALUE event = ATTR(canvas->attr, event);  
      if (! NIL_P(event)) {
        shoes_safe_block(app->canvas, event, rb_ary_new3(1, evt));
        shoes_event *tevent;
        Data_Get_Struct(evt, shoes_event, tevent);
        sendevt = shoes_event_contrain_TF(tevent->accept);
      } else {
        fprintf(stderr, "keyup: doen't have event - but should - dump hash\n");
        shoes_hash_debug(canvas->attr);
      }
    }
    if (sendevt == Qtrue) {
        shoes_canvas_send_keyup(app->canvas, key);
    } 
    return SHOES_OK;
}

#if 0
// replay -- testing - just clicks
debug_value(VALUE obj) {
  switch (TYPE(obj)) {
    case T_NIL: 
      break;
    case T_OBJECT:
      break;
    case T_CLASS: 
      break;
    case T_MODULE:
      break;
    case T_FLOAT:
      break;
    case T_STRING:
      break;
    case T_REGEXP:
      break;
    case T_ARRAY:
      break;
    case T_HASH:
      break;
    case T_STRUCT:    // (Ruby) structure
      break;
    case T_BIGNUM:    // multi precision integer
      break;
    case T_FIXNUM:    // Fixnum(31bit or 63bit integer)
      break;
    case T_COMPLEX:   // complex number
      break;
    case T_RATIONAL:  // rational number
      break;
    case T_FILE:      // IO
      break;
    case T_TRUE:      // true
      break;
    case T_FALSE:     // false
      break;
    case T_DATA:      // data
      break;
    case T_SYMBOL:    // symbol
      break;
    case T_ICLASS:    // included module
      break;
    case T_MATCH:     // MatchData object
      break;
    case T_UNDEF:     // undefined
      break;
    case T_NODE:      // syntax tree node
      break;
    case T_ZOMBIE:    // object awaiting finalization
      break;
    default: 
      break;
  }
}
#endif

VALUE shoes_app_replay_event(VALUE self, VALUE evh) {
  shoes_app *self_t;
  Data_Get_Struct(self, shoes_app, self_t);
  VALUE btn, vx, vy, mods, type, vobj;
  btn = shoes_hash_get(evh, rb_intern("button"));
  vx = shoes_hash_get(evh, rb_intern("x"));
  vy = shoes_hash_get(evh, rb_intern("y"));
  mods = shoes_hash_get(evh, rb_intern("modifiers"));
  type = shoes_hash_get(evh, rb_intern("type"));
  vobj = shoes_hash_get(evh, rb_intern("object"));
  ID typeid = SYM2ID(type);
  // using app->canvas
  if (typeid == s_click) {
    shoes_canvas_send_click(self_t->canvas, NUM2INT(btn), NUM2INT(vx), NUM2INT(vy), mods);
    return Qtrue;
  } else if (typeid == s_btn_activate) {
    // TODO figure out whether it's a button/checkbox/radio and how
    // to call the shoes code
    VALUE button = Qnil;
    int x = NUM2INT(vx);
    int y = NUM2INT(vy);
    //debug_value(vobj);   // it's not one of the documented types.
    shoes_event_find_native(self_t->canvas,  x+4, y+4, &button);
    if (! NIL_P(button)) {
      shoes_control_send(button, s_click);
    }
    return Qtrue;
  } else 
    return Qnil;
}

VALUE shoes_sys(char *cmd, int detach) {
    if (detach)
        return rb_funcall(rb_mKernel, rb_intern("system"), 1, rb_str_new2(cmd));
    else
        return rb_funcall(rb_mKernel, '`', 1, rb_str_new2(cmd));
}

shoes_code shoes_app_goto(shoes_app *app, char *path) {
    shoes_code code = SHOES_OK;
    const char http_scheme[] = "http://";
    if (strlen(path) > strlen(http_scheme) && strncmp(http_scheme, path, strlen(http_scheme)) == 0) {
        shoes_browser_open(path);
    } else {
        code = shoes_app_visit(app, path);
       if (code == SHOES_OK) {
            shoes_app_motion(app, app->mousex, app->mousey, Qnil);
            shoes_slot_repaint(app->slot);
        }
    }
    return code;
}

shoes_code shoes_slot_repaint(SHOES_SLOT_OS *slot) {
    shoes_native_slot_paint(slot);
    return SHOES_OK;
}

static void shoes_style_set(VALUE styles, VALUE klass, VALUE k, VALUE v) {
    VALUE hsh = rb_hash_aref(styles, klass);
    if (NIL_P(hsh))
        rb_hash_aset(styles, klass, hsh = rb_hash_new());
    rb_hash_aset(hsh, k, v);
}

#define STYLE(klass, k, v) \
  shoes_style_set(app->styles, klass, \
    ID2SYM(rb_intern("" # k)), rb_str_new2("" # v))

void shoes_app_reset_styles(shoes_app *app) {
    app->styles = rb_hash_new();
    STYLE(cBanner,      size, 48);
    STYLE(cTitle,       size, 34);
    STYLE(cSubtitle,    size, 26);
    STYLE(cTagline,     size, 18);
    STYLE(cCaption,     size, 14);
    STYLE(cPara,        size, 12);
    STYLE(cInscription, size, 10);

    STYLE(cCode,        family, monospace);
    STYLE(cDel,         strikethrough, single);
    STYLE(cEm,          emphasis, italic);
    STYLE(cIns,         underline, single);
    STYLE(cLink,        underline, single);
    STYLE(cLink,        stroke, #06E);
    STYLE(cLinkHover,   underline, single);
    STYLE(cLinkHover,   stroke, #039);
    STYLE(cStrong,      weight, bold);
    STYLE(cSup,         rise,   10);
    STYLE(cSup,         size,   x-small);
    STYLE(cSub,         rise,   -10);
    STYLE(cSub,         size,   x-small);
}

void shoes_app_style(shoes_app *app, VALUE klass, VALUE hsh) {
    long i;
    VALUE keys = rb_funcall(hsh, s_keys, 0);
    for ( i = 0; i < RARRAY_LEN(keys); i++ ) {
        VALUE key = rb_ary_entry(keys, i);
        VALUE val = rb_hash_aref(hsh, key);
        if (!SYMBOL_P(key)) key = rb_str_intern(key);
        shoes_style_set(app->styles, klass, key, val);
    }
}

VALUE shoes_app_close_window(shoes_app *app) {
    shoes_native_app_close(app);
    return Qnil;
}

VALUE shoes_app_location(VALUE self) {
    shoes_app *app;
    Data_Get_Struct(self, shoes_app, app);
    return app->location;
}

VALUE shoes_app_is_started(VALUE self) {
    shoes_app *app;
    Data_Get_Struct(self, shoes_app, app);
    return app->started ? Qtrue : Qfalse;
}

VALUE shoes_app_contents(VALUE self) {
    shoes_app *app;
    Data_Get_Struct(self, shoes_app, app);
    return shoes_canvas_contents(app->canvas);
}

VALUE shoes_app_quit(VALUE self) {
    shoes_native_quit();
    return self;
}

// Shoes doesn't know much about this - it's mostly C level window stuff
// to handle stdin/stdout and a native window for keypress and display
//
// Ugly: default font size
#ifdef SHOES_QUARTZ
#define TERM_FONT_SZ 12
#else
#define TERM_FONT_SZ 10
#endif
int shoes_global_terminal = 0;
// this called by the Shoes.show_console or using the -w flag on the
// command line.  The next method is the preferred way.

VALUE shoes_app_console(VALUE self) {
    if (!shoes_global_terminal) {
        // Dig out DIR constant
        VALUE dir_val;
        dir_val = rb_const_get(self, rb_intern("DIR"));
        char *dir_path = RSTRING_PTR(dir_val);
        //shoes_global_terminal = shoes_native_console(dir_path);
        shoes_native_terminal(dir_path, -1, 80, 24, TERM_FONT_SZ, "black", "white", "Shoes Terminal");
        shoes_global_terminal = 1;
    }
    return shoes_global_terminal ? Qtrue : Qfalse;
}
// This is called from Shoes with a 'Shoes.terminal {hash of args values}'
// THE prefered way to get a terminal/console. This parses the ruby hash in
// argv
VALUE shoes_app_terminal(int argc, VALUE *argv, VALUE self) {
    if (!shoes_global_terminal) {
        // Dig out DIR constant
        VALUE dir_val;
        dir_val = rb_const_get(self, rb_intern("DIR"));
        // set sensible defaults to be replaced if specified
        int monitor = -1, columns = 80, rows = 24, fontsize = TERM_FONT_SZ;
        char *fg = "black";
        char* bg = "white";
        char* title = "Shoes Terminal";
        char *dir_path = RSTRING_PTR(dir_val);
        if (argc == 1) {
            // parse the hash args
            VALUE argtitle = shoes_hash_get(argv[0], rb_intern("title"));
            if (!(NIL_P(argtitle)))
                title = RSTRING_PTR(argtitle);
            VALUE argcol = shoes_hash_get(argv[0], rb_intern("columns"));
            if (!(NIL_P(argcol)))
                columns = NUM2INT(argcol);
            VALUE argrow = shoes_hash_get(argv[0], rb_intern("rows"));
            if (!NIL_P(argrow))
                rows = NUM2INT(argrow);
            VALUE argfz = shoes_hash_get(argv[0], rb_intern("fontsize"));
            if (!NIL_P(argfz))
                fontsize = NUM2INT(argfz);
            VALUE argfg = shoes_hash_get(argv[0], rb_intern("fg"));
            if (!NIL_P(argfg))
                fg = RSTRING_PTR(argfg);
            VALUE argbg = shoes_hash_get(argv[0], rb_intern("bg"));
            if (!NIL_P(argbg))
                bg = RSTRING_PTR(argbg);
            VALUE argmon = shoes_hash_get(argv[0], rb_intern("monitor"));
            if (!NIL_P(argmon))
                monitor = NUM2INT(argmon);
#if 0
            VALUE modearg = shoes_hash_get(argv[0], rb_intern("mode"));
            if (!NIL_P(modearg)) {
                char *arg = RSTRING_PTR(modearg);
                if (strcmp(arg, "game") == 0)
                    mode = 0;
            }
#endif
        }
        fprintf(stderr, "DIR: %s\n", dir_path);
        shoes_native_terminal(dir_path, monitor, columns, rows, fontsize, fg, bg, title);
        shoes_global_terminal = 1;
        fprintf(stderr, "Terminal set: %s\n", title);
    }
    return shoes_global_terminal ? Qtrue : Qfalse;
}

/* -------     monitor     ------ */

VALUE shoes_app_monitor_get(VALUE self) {
  shoes_app *app;
  Data_Get_Struct(self, shoes_app, app);
  return INT2NUM(shoes_native_monitor_get(app));
}

VALUE shoes_app_monitor_set(VALUE self, VALUE mon) {
  shoes_app *app;
  Data_Get_Struct(self, shoes_app, app);
  app->monitor = NUM2INT(mon);
  shoes_native_monitor_set(app);
  return INT2NUM(app->monitor);
}

/* ----------- app id (serial number) -------*/
VALUE shoes_app_id(VALUE self) {
  char buf[10];
  shoes_app *app;
  Data_Get_Struct(self, shoes_app, app);
  sprintf(buf,"AppID%d", app->id);
  return rb_str_new2(buf);
}
