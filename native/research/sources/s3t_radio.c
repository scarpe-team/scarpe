#include "shoes/types/native.h"
#include "shoes/types/radio.h"

// ruby
VALUE cRadio;

FUNC_M("+radio", radio, -1);

void shoes_radio_init() {
    cRadio  = rb_define_class_under(cTypes, "Radio", cNative);
    rb_define_method(cRadio, "draw", CASTHOOK(shoes_radio_draw), 2);
    rb_define_method(cRadio, "checked?", CASTHOOK(shoes_check_is_checked), 0);
    rb_define_method(cRadio, "checked=", CASTHOOK(shoes_check_set_checked_m), 1);
    rb_define_method(cRadio, "click", CASTHOOK(shoes_control_click), -1);
    rb_define_method(cRadio, "tooltip", CASTHOOK(shoes_control_get_tooltip), 0);
    rb_define_method(cRadio, "tooltip=", CASTHOOK(shoes_control_set_tooltip), 1);

    RUBY_M("+radio", radio, -1);
}

// ruby
extern int shoes_app_serial_num;

VALUE shoes_radio_draw(VALUE self, VALUE c, VALUE actual) {
  SETUP_CONTROL(0, 20, FALSE);

  if (RTEST(actual)) {
    if (self_t->ref == NULL) {
      VALUE group = ATTR(self_t->attr, group);
      if (NIL_P(group)) {
        shoes_canvas *canvas;
        Data_Get_Struct(c, shoes_canvas, canvas);
        ++shoes_app_serial_num;
        char buf[20];
        sprintf(buf, "grprad_%d", shoes_app_serial_num);
        VALUE grpstr = rb_str_new2(buf);
        group = rb_to_symbol(grpstr);
      }
      if (TYPE(canvas->app->groups) != T_HASH) {
        //fprintf(stderr, "Oops - not a hash\n");
        canvas->app->groups = rb_hash_new();
      }
      VALUE glist = rb_hash_aref(canvas->app->groups, group);
      if (NIL_P(glist)) {
          rb_hash_aset(canvas->app->groups, group, rb_ary_new3(1, self));
      } else {
          rb_ary_push(glist, self);
      }
      glist = rb_hash_aref(canvas->app->groups, group);
      // debugging 
      VALUE gstr = rb_sym_to_s(group); 
      if (TYPE(glist) != T_ARRAY)
        fprintf(stderr, "group is not array\n");
      /*
      else
        fprintf(stderr, "group %s has %d entries\n", RSTRING_PTR(gstr), (int)RARRAY_LEN(glist));
      */
      self_t->ref = shoes_native_radio(self, canvas, &place, self_t->attr, glist);

      if (RTEST(ATTR(self_t->attr, checked)))
          shoes_native_check_set(self_t->ref, Qtrue);
      shoes_control_check_styles(self_t);
      shoes_native_control_position(self_t->ref, &self_t->place, self, canvas, &place);
    } else
      // ref != null  (native widget exists)
      shoes_native_control_repaint(self_t->ref, &self_t->place, canvas, &place);
  }

  FINISH();

  return self;
}

VALUE shoes_check_set_checked_m(VALUE self, VALUE on) {
#if 0
  if (RTEST(on)) {
      VALUE glist = shoes_radio_group(self);

      if (!NIL_P(glist)) {
          long i;
          for (i = 0; i < RARRAY_LEN(glist); i++) {
              VALUE ele = rb_ary_entry(glist, i);
              shoes_check_set_checked(ele, ele == self ? Qtrue : Qfalse);
          }
      } else {
          shoes_check_set_checked(self, on);
      }
      return on;
  }
#endif
  shoes_check_set_checked(self, on);
  return on;
}

#ifdef SHOES_FORCE_RADIO
// called by shoes 'radio.check = <bool> ?
void shoes_radio_button_click(VALUE control) {
    shoes_check_set_checked_m(control, Qtrue);
}
#endif

VALUE shoes_radio_group(VALUE self) {
    GET_STRUCT(control, self_t);
    if (!NIL_P(self_t->parent)) {
        shoes_canvas *canvas;
        VALUE group = ATTR(self_t->attr, group);
        if (NIL_P(group)) group = self_t->parent;
        Data_Get_Struct(self_t->parent, shoes_canvas, canvas);
        return shoes_hash_get(canvas->app->groups, group);
    }
    return Qnil;
}

/*
 *  This is one twiddly bit of work - find the radio in the group(s)
 *  and remove it from the group
 *  Uses a callback for rb_hash_each
 */
static int shoes_radio_group_keys(VALUE key, VALUE val, VALUE arg) {
  //called for each hash key, value is an Array of 'shoes_control'
  if (RB_TYPE_P(val, T_ARRAY)) {
    //printf("Array len: %d\n",  (int)RARRAY_LEN(val));
    SHOES_CONTROL_REF ref = (SHOES_CONTROL_REF)arg;
    int i;
    for (i = 0; i < RARRAY_LEN(val); i++) {
      shoes_control *ctrl;
      VALUE entry = rb_ary_entry(val, i);
      Data_Get_Struct(entry, shoes_control, ctrl);
      if ( ctrl->ref == ref) {
        //printf("FOUND RADIO in group\n");
        rb_ary_delete_at(val, i);
        break;
      }
    }
  }
  
  return ST_CONTINUE;
}

void shoes_radio_remove_group(SHOES_CONTROL_REF ref, VALUE grp_hash) {
  if (!RB_TYPE_P(grp_hash, T_HASH))
    fprintf(stderr, "radio_group not a hash\n");
  rb_hash_foreach(grp_hash, shoes_radio_group_keys, (VALUE)ref);
}

// canvas
VALUE shoes_canvas_radio(int argc, VALUE *argv, VALUE self) {
    rb_arg_list args;
    VALUE group = Qnil, attr = Qnil, radio;
    SETUP_CANVAS();

    switch (rb_parse_args(argc, argv, "h,o|h,", &args)) {
        case 1:
            attr = args.a[0];
            break;

        case 2:
            group = args.a[0];
            attr = args.a[1];
            break;
    }

    if (!NIL_P(group))
        ATTRSET(attr, group, group);
    if (rb_block_given_p())
        ATTRSET(attr, click, rb_block_proc());

    radio = shoes_control_new(cRadio, attr, self);
    shoes_add_ele(canvas, radio);
    return radio;
}
