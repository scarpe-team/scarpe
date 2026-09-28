///
// shoes/world.c
// Abstract windowing for GTK, Quartz (OSX) and Win32.
//
#include "shoes/app.h"
#include "shoes/ruby.h"
#include "shoes/config.h"
#include "shoes/world.h"
#include "shoes/native/native.h"
#include "shoes/internal.h"
#include "shoes/types/settings.h"

#ifdef SHOES_SIGNAL
#include <signal.h>
#ifdef SHOES_GTK_WIN32
#define SHOES_WIN32  // For this file.
#endif

void shoes_sigint() {
    shoes_native_quit();
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
#ifdef SHOES_QUARTZ
extern void shoes_osx_setup_stdout();
#endif
shoes_world_t *shoes_world = NULL;

shoes_world_t *shoes_world_alloc() {
    shoes_world_t *world = SHOE_ALLOC(shoes_world_t);
    SHOE_MEMZERO(world, shoes_world_t, 1);
    world->apps = rb_ary_new();
    world->msgs = rb_ary_new();
    world->mainloop = FALSE;
    world->image_cache = st_init_strtable();
    world->blank_image = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1, 1);
    world->blank_cache = SHOE_ALLOC(shoes_cached_image);
    world->blank_cache->surface = world->blank_image;
    world->blank_cache->pattern = NULL;
    world->blank_cache->width = 1;
    world->blank_cache->height = 1;
    world->blank_cache->mtime = 0;
    world->default_font = pango_font_description_new();
    pango_font_description_set_family(world->default_font, "Arial");
    pango_font_description_set_absolute_size(world->default_font, 14. * PANGO_SCALE * (96./72.));
    rb_gc_register_address(&world->apps);
    rb_gc_register_address(&world->msgs);
    // new settings 
    world->settings = shoes_settings_alloc(cSettings);
    rb_gc_register_address(&world->settings);
    return world;
}

int shoes_world_free_image_cache(char *key, shoes_cache_entry *cached, char *arg) {
    if (cached->type != SHOES_CACHE_ALIAS && cached->image != NULL) {
        if (cached->image->pattern != NULL)
            cairo_pattern_destroy(cached->image->pattern);
        if (cached->image->surface != shoes_world->blank_image)
            cairo_surface_destroy(cached->image->surface);
        free(cached->image);
    }
    free(cached);
    free(key);
    return ST_CONTINUE;
}

void shoes_world_free(shoes_world_t *world) {
    shoes_native_cleanup(world);
    st_foreach(world->image_cache, CASTFOREACH(shoes_world_free_image_cache), 0);
    st_free_table(world->image_cache);
    SHOE_FREE(world->blank_cache);
    cairo_surface_destroy(world->blank_image);
    pango_font_description_free(world->default_font);
    rb_gc_unregister_address(&world->apps);
    rb_gc_unregister_address(&world->msgs);
    if (world != NULL)
        SHOE_FREE(world);
}

int shoes_ruby_embed() {
    VALUE v;
    char *argv[] = {"ruby", "-e", "1"};
    //char *argv[] = {"ruby_engine", "-e", "1"};
    RUBY_INIT_STACK;
#ifdef SHOES_WIN32
    //ruby_sysinit(0, 0);
#endif
    /* in ruby 2.3+ we need to give ruby_sysinit something nullish  */
    //int zedc = 0;
    //int *zeda = &zedc;
    int zedc = 0;
    char *zedb = (char *)&zedc;
    char **zeda = &zedb;
    ruby_sysinit(&zedc, &zeda);
    ruby_init();
    v = (VALUE)ruby_options(3, argv);
    return !FIXNUM_P(v);
}

shoes_code shoes_init(SHOES_INIT_ARGS) {
    //printf("starting shoes_init\n");
#ifdef SHOES_SIGNAL
    signal(SIGINT,  shoes_sigint);
#ifndef SHOES_GTK_WIN32
    signal(SIGQUIT, shoes_sigint);
#endif
#endif
#ifdef SHOES_QUARTZ
    // init some OSX things our way before Ruby inits.
    shoes_osx_setup_stdout();
#endif
    shoes_ruby_embed();  // initialize ruby
    shoes_ruby_init();
    shoes_world = shoes_world_alloc();
#ifdef SHOES_WIN32
    shoes_world->os.instance = inst;
    shoes_world->os.style = style;
#endif
    // parse shoes.yaml file and update settings class/object
    shoes_init_load_yaml(path);
    
    shoes_native_init();

    rb_const_set(cShoes, rb_intern("FONTS"), shoes_font_list());
    return SHOES_OK;
}

void shoes_update_fonts(VALUE ary) {
#if PANGO_VERSION_MAJOR > 1 || PANGO_VERSION_MINOR >= 22
    pango_cairo_font_map_set_default(NULL);
#endif
    rb_funcall(rb_const_get(cShoes, rb_intern("FONTS")), rb_intern("replace"), 1, ary);
}

static VALUE shoes_load_begin(VALUE v) {
    char *bootup = (char *)v;
    return rb_eval_string(bootup);
}

static VALUE shoes_load_exception(VALUE v, VALUE exc) {
    return exc;
}

shoes_code shoes_load(char *path) {
    char bootup[SHOES_BUFSIZE];

    if (path) {
        sprintf(bootup, "Shoes.visit(%%q<%s>);", path);

        VALUE v = rb_rescue2(CASTHOOK(shoes_load_begin), (VALUE)bootup, CASTHOOK(shoes_load_exception), Qnil, rb_cObject, 0);
        if (rb_obj_is_kind_of(v, rb_eException)) {
            shoes_canvas_error(Qnil, v);
            rb_eval_string("Shoes.show_log");
        }
    }

    return SHOES_OK;
}

void shoes_set_argv(int argc, char **argv) {
    ruby_set_argv(argc, argv);
}

#ifdef SHOES_QUARTZ
static VALUE shoes_start_begin(VALUE v) {
    char str[128];
    sprintf(str, "$SHOES_URI = Shoes.args!(%d)", osx_cshoes_launch);
    return rb_eval_string(str);
}
#else
static VALUE shoes_start_begin(VALUE v) {
    return rb_eval_string("$SHOES_URI = Shoes.args!");
}
#endif

static VALUE shoes_start_exception(VALUE v, VALUE exc) {
    return exc;
}

shoes_code shoes_start(char *path, char *uri, int debug) {
    shoes_code code = SHOES_OK;
    char bootup[SHOES_BUFSIZE];
    char dbstr[64];
    sprintf(dbstr, "SHOES_DEBUG=%s", (debug ? "true" : "false"));
    rb_eval_string(dbstr);
    int len = shoes_snprintf(bootup,
                             SHOES_BUFSIZE,
                             "begin;"
                             "DIR = File.expand_path(File.dirname(%%q<%s>));"
#ifdef OLD_SHOES
                             "$:.replace([DIR+'/ruby/lib/'+(ENV['SHOES_RUBY_ARCH'] || RUBY_PLATFORM), DIR+'/ruby/lib', DIR+'/lib', '.']);"
#else
                             "$:.unshift(DIR+'/lib');"
                             "$:.unshift('.');"
#endif
                             "require 'shoes';"
                             "DIR;"
                             "rescue Object => e;"
                             "puts(e.message);"
                             "end",
                             path);

    if (len < 0 || len >= SHOES_BUFSIZE) {
        QUIT("Path to script is too long.");
    }

    VALUE str = rb_eval_string(bootup);
    if (NIL_P(str))
        return SHOES_QUIT;

    StringValue(str);
    strcpy(shoes_world->path, RSTRING_PTR(str));

    char *load_uri_str = NULL;
    VALUE load_uri = rb_rescue2(CASTHOOK(shoes_start_begin), Qnil, CASTHOOK(shoes_start_exception), Qnil, rb_cObject, 0);
    if (!RTEST(load_uri))
        return SHOES_QUIT;
    if (rb_obj_is_kind_of(load_uri, rb_eException)) {
        QUIT_ALERT(load_uri);
    }

    if (rb_obj_is_kind_of(load_uri, rb_cString))
        load_uri_str = RSTRING_PTR(load_uri);

    code = shoes_load(load_uri_str);
    if (code != SHOES_OK)
        goto quit;

    code = shoes_app_start(shoes_world->apps, uri);
quit:
    return code;
}

shoes_code shoes_final() {
    rb_funcall(cShoes, rb_intern("clean"), 0);
    shoes_world_free(shoes_world);
    return SHOES_OK;
}

/*
 * load the shoes.yaml file (if it exists and is formatted properly)
 * borrowed from https://stackoverflow.com/questions/20628099/parsing-yaml-to-values-with-libyaml-in-c
*/
#include <stdio.h>
#include <string.h>
#include <yaml.h>
// Another C global
shoes_yaml_init *shoes_config_yaml = NULL; 

int shoes_init_load_yaml(char *path) {
    yaml_parser_t parser;
    yaml_token_t token;
    if (!yaml_parser_initialize(&parser)) {
        fputs("Failed to initialize yaml parser!\n", stderr);
        return 0;
    }
    // set defaults
    shoes_config_yaml = malloc(sizeof(shoes_yaml_init));
    shoes_config_yaml->app_name = "Shoes";
    shoes_config_yaml->icon_path = "static/app-icon.png";
    shoes_config_yaml->theme_name = NULL;
    shoes_config_yaml->active = FALSE;
    shoes_config_yaml->rdomain = "com.shoesrb.shoes";
    shoes_config_yaml->use_menus = "false";
    shoes_config_yaml->mdi = "false";
    shoes_config_yaml->backend = NULL;
    shoes_config_yaml->extra1 = NULL;
    shoes_config_yaml->extra2 = NULL;
    shoes_config_yaml->osx_menutrim = "false";
    shoes_config_yaml->image_cache = "true";
    
    // check current dir (script location) first
    FILE* fh = fopen("startup.yaml", "r");
    if (fh == NULL) {
      // check where Shoes was launched from - argv[0] sort-of). 
      // We don't have DIR yet so do what it does
      char buf[200];
      sprintf(buf, "File.expand_path(File.dirname(%%q<%s>));", path);
      VALUE dpv = rb_eval_string(buf);
      char *dp = RSTRING_PTR(dpv);
      strcpy(buf, dp);
      strcat(buf,"/startup.yaml");
      fh = fopen(buf, "r");
    }
    if (fh != NULL) {
      yaml_parser_set_input_file(&parser, fh);
      /* As this is an example, I'll just use:
       *  state = 0 = expect key
       *  state = 1 = expect value
       */
      int state = 0;
      char** datap;
      char* tk;
  
      do {
          yaml_parser_scan(&parser, &token);
          switch(token.type) {
              case YAML_KEY_TOKEN:     state = 0; break;
              case YAML_VALUE_TOKEN:   state = 1; break;
              case YAML_SCALAR_TOKEN:
                  tk = (char *)token.data.scalar.value;
                  if (state == 0) {
                      /* It's safe to not use strncmp as 
                         one string is a literal */
                      if (!strcmp(tk, "App_Name")) {
                          datap = &shoes_config_yaml->app_name;
                      } else if (!strcmp(tk,"Icon_Path")) {
                          datap = &shoes_config_yaml->icon_path;
                      } else if (!strcmp(tk, "Theme")) {
                          datap = &shoes_config_yaml->theme_name;
                      } else if (!strcmp(tk,"RDomain")) {
                          datap = &shoes_config_yaml->rdomain;
                      } else if (!strcmp(tk,"Use_Menus")) {
                          datap = &shoes_config_yaml->use_menus;
                      } else if (!strcmp(tk,"MDI")) {
                          datap = &shoes_config_yaml->mdi;
                      } else if (!strcmp(tk,"Extra1")) {
                          datap = &shoes_config_yaml->extra1;
                      } else if (!strcmp(tk,"Extra2")) {
                          datap = &shoes_config_yaml->extra2;
                      } else if (!strcmp(tk, "Image_Cache")) {
                          datap = &shoes_config_yaml->image_cache;
                      } else if (!strcmp(tk,"OSX_Menu_Trim")) {
                          datap = &shoes_config_yaml->osx_menutrim;
                      } else if (!strcmp(tk,"Display_Backend")) {
                          datap = &shoes_config_yaml->backend; 
                      } else {
                          printf("Unrecognised key: %s\n", tk);
                          return 0;
                      }
                  } else {
                        *datap = strdup(tk);
                  }
                  break;
             default: break;
             }
         if (token.type != YAML_STREAM_END_TOKEN)
             yaml_token_delete(&token);
      } while (token.type != YAML_STREAM_END_TOKEN);
  
      yaml_token_delete(&token);
      yaml_parser_delete(&parser);
      fclose(fh);
    }
    shoes_config_yaml->active = TRUE;
    shoes_settings_new(shoes_config_yaml);
    return 1;
}

#ifdef __cplusplus
}
#endif
