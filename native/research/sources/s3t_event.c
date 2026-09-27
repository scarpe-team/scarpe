
#include "shoes/types/event.h"
#include "shoes/types/svg.h"

VALUE cShoesEvent; 

FUNC_M("+shoesevent", shoesevent, -1);

void shoes_shoesevent_init() {
    cShoesEvent = rb_define_class_under(cTypes, "ShoesEvent", cNative); 
    rb_define_alloc_func(cShoesEvent, shoes_event_alloc);
    rb_define_method(cShoesEvent, "type", CASTHOOK(shoes_event_type), 0);
    rb_define_method(cShoesEvent, "object", CASTHOOK(shoes_event_object), 0);
    rb_define_method(cShoesEvent, "accept", CASTHOOK(shoes_event_get_accept),0);
    rb_define_method(cShoesEvent, "accept=", CASTHOOK(shoes_event_set_accept),1);
    rb_define_method(cShoesEvent, "button", CASTHOOK(shoes_event_button), 0);
    rb_define_method(cShoesEvent, "x", CASTHOOK(shoes_event_x), 0);
    rb_define_method(cShoesEvent, "y", CASTHOOK(shoes_event_y), 0);
    rb_define_method(cShoesEvent, "width", CASTHOOK(shoes_event_width), 0);
    rb_define_method(cShoesEvent, "height", CASTHOOK(shoes_event_height), 0);
    rb_define_method(cShoesEvent, "key", CASTHOOK(shoes_event_key), 0);
    rb_define_method(cShoesEvent, "key=", CASTHOOK(shoes_event_set_key), 1);
    rb_define_method(cShoesEvent, "modifiers", CASTHOOK(shoes_event_modifiers), 0);
    RUBY_M("+shoesevent", shoesevent, -1);
}
 
// ruby
void shoes_event_mark(shoes_event *event) {
    rb_gc_mark_maybe(event->type);
    rb_gc_mark_maybe(event->object);
    rb_gc_mark_maybe(event->key);
    rb_gc_mark_maybe(event->accept);
   rb_gc_mark_maybe(event->modifiers);
}

void shoes_event_free(shoes_event *event) {
    RUBY_CRITICAL(free(event));
}

// users should not create events but something has to be visible. 
// click calls here.
VALUE shoes_event_new(VALUE klass, ID type, VALUE widget, int x, int y, int btn, VALUE mods, VALUE key) {
    shoes_event *event;
    VALUE obj = shoes_event_alloc(klass);
    Data_Get_Struct(obj, shoes_event, event);
    event->accept = Qtrue;
    event->type = type;
    event->object = widget;
    event->x = x;
    event->y = y;
    event->btn = btn;
    event->key = Qnil;
    event->modifiers = mods;
    event->key = key;
    return obj;
}
// Or here 
VALUE shoes_event_new_widget(VALUE klass, ID type, VALUE widget, int btn, int x,
        int y, int w, int h, VALUE modifiers, VALUE key) {
    shoes_event *event;
    VALUE obj = shoes_event_alloc(klass);
    Data_Get_Struct(obj, shoes_event, event);
    event->accept = Qtrue;
    event->type = type;
    event->object = widget;
    event->btn = btn;
    event->x = x;
    event->y = y;
    event->width = w;
    event->height = h;
    event->key = Qnil;
    event->modifiers = modifiers;
    return obj;
}

VALUE shoes_event_new_key(VALUE klass, ID type, VALUE key) {
    shoes_event *event;
    VALUE obj = shoes_event_alloc(klass);
    Data_Get_Struct(obj, shoes_event, event);
    event->accept = Qtrue;
    event->type = type;
    event->object = Qnil;
    event->btn = 0;
    event->x = 0;
    event->y = 0;
    event->width = 0;
    event->height = 0;
    event->key = key;
    event->modifiers = Qnil;
    return obj;
}

VALUE shoes_event_alloc(VALUE klass) {
    VALUE obj;
    shoes_event *event = SHOE_ALLOC(shoes_event);
    SHOE_MEMZERO(event, shoes_event, 1);
    obj = Data_Wrap_Struct(klass, shoes_event_mark, shoes_event_free, event);
    event->type = Qnil;
    event->object = Qnil;
 
    return obj;
}


VALUE shoes_canvas_shoesevent(int argc, VALUE *argv, VALUE self) {
    VALUE ev = Qnil;
    SETUP_CANVAS();
    // Parse the hash args
    VALUE hsh = argv[0];
    VALUE typeq = shoes_hash_get(hsh, rb_intern("type"));
    ID type;
    if (TYPE(typeq) == T_SYMBOL) {
      type = SYM2ID(typeq);
    } else {
      type = rb_intern(RSTRING_PTR(typeq));
    }

    //if (type == s_click)
    //  fprintf(stderr, "made a s_click\n");
    VALUE obj = Qnil;
    int x = NUM2INT(shoes_hash_get(hsh, rb_intern("x")));
    int y = NUM2INT(shoes_hash_get(hsh, rb_intern("y")));
    int btn = NUM2INT(shoes_hash_get(hsh, rb_intern("button")));
    ev = shoes_event_new(cShoesEvent,type,obj,x,y,btn,Qnil,Qnil);
    return ev;
}

/* Need to detect if this is a click on pseudo widget (img,svg,plot.user-widget)
 * or a slot click handler before we pass it to shoes_canvas_send_click/click2
 * We create different event objects for the user specified handler to deal with
*/
extern ID cTextBlock, cImage, cShape, cCanvas;
 
VALUE shoes_event_create_event(shoes_app *app, ID etype, int button, int x, int y, VALUE modifiers,VALUE key) {
  VALUE nobj;
  VALUE ps_widget = shoes_event_find_psuedo (app->canvas, x, y, &nobj);
  VALUE evt;
  if (NIL_P(ps_widget)) {
    evt = shoes_event_new(cShoesEvent, etype, Qnil, x, y, button, modifiers,key);
  } else {
    // TODO: ASSUME all the ps_widget have the canvas place
    int w,h; 
    shoes_canvas *cvs;
    Data_Get_Struct(nobj, shoes_canvas, cvs);
    w = cvs->place.w;
    h = cvs->place.h;
    evt = shoes_event_new_widget(cShoesEvent, etype, nobj, button, x, y, w, h, modifiers, key);
  }
  return evt;
}

/*
 * Yes it does seem to be expensive but events happen at user speed (slow)
 * Recursive when it finds a new slot (canvas) 
 * Beware all these non-widgets are canvas based! Return Qnil if no non-natives
 * match the x,y. Return the matching non-native (not it's containing canvas/slot)
*/
VALUE shoes_event_find_psuedo (VALUE self, int x, int y, VALUE *hitobj) {
    long i;
    int ox = x, oy = y;
    VALUE v = Qnil;  //  v is t/f, Qtrue/Qnil
    shoes_canvas *self_t;
    Data_Get_Struct(self, shoes_canvas, self_t);

    if (ORIGIN(self_t->place)) {
        oy = y + self_t->slot->scrolly;
        ox = x - self_t->place.ix + self_t->place.dx;
        oy = oy - (self_t->place.iy + self_t->place.dy);
        if (oy < self_t->slot->scrolly || ox < 0 || oy > self_t->slot->scrolly + self_t->place.ih || ox > self_t->place.iw)
            return Qnil;
    }
    if (ATTR(self_t->attr, hidden) != Qtrue) {
        if (self_t->app->canvas == self) // when we are the app's slot
            y -= self_t->slot->scrolly;

        if (IS_INSIDE(self_t, x, y)) {
            // TODO:  something
            VALUE click = ATTR(self_t->attr, click);
            if (!NIL_P(click)) {
                if (ORIGIN(self_t->place))
                    y += self_t->slot->scrolly;
                //hoes_safe_block(self, click, rb_ary_new3(4, INT2NUM(button), INT2NUM(x), INT2NUM(y), mods));
            }
        }

        for (i = RARRAY_LEN(self_t->contents) - 1; i >= 0; i--) {
            VALUE ele = rb_ary_entry(self_t->contents, i);
            if (rb_obj_is_kind_of(ele, cCanvas)) {
                v = shoes_event_find_psuedo(ele, ox, oy, hitobj);
            } else if (rb_obj_is_kind_of(ele, cTextBlock)) {
                v = shoes_textblock_event_is_here(ele, ox, oy);
                *hitobj = ele;
            } else if (rb_obj_is_kind_of(ele, cImage)) {
                v = shoes_image_event_is_here(ele, ox, oy);
                *hitobj = ele;
            } else if (rb_obj_is_kind_of(ele, cSvg)) {
                v = shoes_svg_event_is_here(ele, ox, oy);
                *hitobj  = ele;
            
            } else if (rb_obj_is_kind_of(ele, cPlot)) {
                v = shoes_plot_event_is_here(ele, ox, oy);
                *hitobj = ele;
            
            } else if (rb_obj_is_kind_of(ele, cShape)) {
                v = shoes_shape_event_is_here(ele, ox, oy);
                *hitobj = ele;
            }

            if (!NIL_P(v))
                return v;
        }
    }

    return Qnil;
}
extern VALUE cButton, cCheck, cRadio;
/* 
 * This is called by event replay to find if there is a native widget at x,y
 */
VALUE shoes_event_find_native (VALUE self, int x, int y, VALUE *hitobj) {
    long i;
    int ox = x, oy = y;
    VALUE v = Qnil;  //  v is t/f, Qtrue/Qnil
    shoes_canvas *self_t;
    Data_Get_Struct(self, shoes_canvas, self_t);

    if (ORIGIN(self_t->place)) {
        oy = y + self_t->slot->scrolly;
        ox = x - self_t->place.ix + self_t->place.dx;
        oy = oy - (self_t->place.iy + self_t->place.dy);
        if (oy < self_t->slot->scrolly || ox < 0 || oy > self_t->slot->scrolly + self_t->place.ih || ox > self_t->place.iw)
            return Qnil;
    }
    if (ATTR(self_t->attr, hidden) != Qtrue) {
        if (self_t->app->canvas == self) // when we are the app's slot
            y -= self_t->slot->scrolly;

        if (IS_INSIDE(self_t, x, y)) {
            // TODO:  something
            VALUE click = ATTR(self_t->attr, click);
            if (!NIL_P(click)) {
                if (ORIGIN(self_t->place))
                    y += self_t->slot->scrolly;
                //shoes_safe_block(self, click, rb_ary_new3(4, INT2NUM(button), INT2NUM(x), INT2NUM(y), mods));
            }
        }

        for (i = RARRAY_LEN(self_t->contents) - 1; i >= 0; i--) {
            VALUE ele = rb_ary_entry(self_t->contents, i);
            if (rb_obj_is_kind_of(ele, cCanvas)) {
                v = shoes_event_find_native(ele, ox, oy, hitobj);
            } else if (rb_obj_is_kind_of(ele, cNative)) {
              v = shoes_control_is_here(ele, ox,oy);
              *hitobj = ele;
            }

            if (!NIL_P(v))
                return v;
        }
    }

    return Qnil;
}


VALUE shoes_event_type(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return ID2SYM(event->type);
}

VALUE shoes_event_object(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return event->object;
}

VALUE shoes_event_get_accept(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return event->accept;
}

VALUE shoes_event_set_accept(VALUE self, VALUE tf) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    event->accept = tf;
    return tf;
}
VALUE shoes_event_button(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return INT2NUM(event->btn);
}
VALUE shoes_event_x(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return INT2NUM(event->x);
}
VALUE shoes_event_y(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return INT2NUM(event->y);
}

VALUE shoes_event_height(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return INT2NUM(event->height);
}
VALUE shoes_event_width(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return INT2NUM(event->width);
}

VALUE shoes_event_key(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);
    return event->key;
}
VALUE shoes_event_set_key(VALUE self, VALUE key) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);  
    return INT2NUM(event->key);
}
VALUE shoes_event_modifiers(VALUE self) {
    shoes_event *event;
    Data_Get_Struct(self, shoes_event, event);  
    return event->modifiers;
}
 
// returns Qtrue or Qfalse 
VALUE shoes_event_contrain_TF(VALUE val) {
  if (NIL_P(val) || val == Qfalse)
    return Qfalse;
  return Qtrue;
}
