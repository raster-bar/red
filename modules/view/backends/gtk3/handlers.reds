Red/System [
	Title:	"GTK3 widget handlers"
	Author: "Qingtian Xie"
	File: 	%handlers.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

gtk-app-activate: func [
	[cdecl]
	app		[handle!]
	data	[int-ptr!]
	/local
		win [handle!]
][
	probe "active"
]

set-selected: func [
	obj [handle!]
	ctx [node!]
	idx [integer!]
	/local
		int [red-integer!]
][
	int: as red-integer! get-node-facet ctx FACE_OBJ_SELECTED
	int/header: TYPE_INTEGER
	int/value: idx
]

set-text: func [
	obj		[handle!]
	ctx		[node!]
	text	[c-string!]
	/local
		size [integer!]
		str	 [red-string!]
		face [red-object!]
		out	 [c-string!]
][
	size: length? text
	if size >= 0 [
		str: as red-string! get-node-facet ctx FACE_OBJ_TEXT
		if TYPE_OF(str) <> TYPE_STRING [
			string/make-at as red-value! str size UCS-2
		]
		if size = 0 [
			string/rs-reset str
			exit
		]
		unicode/load-utf8-buffer text size GET_BUFFER(str) null no
		
		face: push-face obj
		if TYPE_OF(face) = TYPE_OBJECT [
			ownership/bind as red-value! str face _text
		]
		stack/pop 1
	]
]

button-clicked: func [
	[cdecl]
	widget	[handle!]
	ctx		[node!]
][
	make-event widget 0 EVT_CLICK
]

button-toggled: func [
	[cdecl]
	button	[handle!]
	ctx		[node!]
	/local
		bool		  [red-logic!]
		type		  [integer!]
		undetermined? [logic!]
][
	bool: as red-logic! get-node-facet ctx FACE_OBJ_DATA
	undetermined?: gtk_toggle_button_get_inconsistent button

	either undetermined? [
		type: TYPE_OF(bool)
		bool/header: TYPE_NONE						;-- NONE indicates undeterminate
	][
		bool/value: gtk_toggle_button_get_active button
	]
	make-event button 0 EVT_CHANGE
]

base-draw: func [
	[cdecl]
	widget	[handle!]
	cr		[handle!]
	ctx		[node!]
	return: [logic!]
	/local
		vals [red-value!]
		draw [red-block!]
		clr  [red-tuple!]
][
	vals: get-node-values ctx
	draw: as red-block! vals + FACE_OBJ_DRAW
	clr:  as red-tuple! vals + FACE_OBJ_COLOR
	if TYPE_OF(clr) = TYPE_TUPLE [
		set-source-color cr clr/array1
		cairo_paint cr								;-- paint background
	]
	do-draw cr null draw no yes yes yes
	false
]

window-delete-event: func [
	[cdecl]
	widget	[handle!]
	event	[handle!]
	exit-lp	[int-ptr!]
	return: [logic!]
][
	false
]

window-removed-event: func [
	[cdecl]
	app		[handle!]
	widget	[handle!]
	count	[int-ptr!]
][
	count/value: count/value - 1
]

range-value-changed: func [
	[cdecl]
	range	[handle!]
	ctx		[node!]
	/local
		vals  [red-value!]
		val   [float!]
		size  [red-pair!]
	;	type  [red-word!]
		pos   [red-float!]
	;	sym   [integer!]
		max   [float!]
][
	; This event happens on GtkRange widgets including GtkScale.
	; Will any other widget need this?
	vals: get-node-values ctx
	;type:	as red-word!	vals + FACE_OBJ_TYPE
	size:	as red-pair!	vals + FACE_OBJ_SIZE
	pos:	as red-float!	vals + FACE_OBJ_DATA

	;sym:	symbol/resolve type/symbol

	;if type = slider [
	val: gtk_range_get_value range
	either size/y > size/x [
		max: as-float size/y
		val: max - val
	][
		max: as-float size/x
	]
	pos/value: val / max
	make-event range 0 EVT_CHANGE
	;]
]

combo-selection-changed: func [
	[cdecl]
	widget	[handle!]
	ctx		[node!]
	/local
		idx [integer!]
		res [integer!]
		text [c-string!]
][
	idx: gtk_combo_box_get_active widget
	if idx >= 0 [
		res: make-event widget idx + 1 EVT_SELECT
		set-selected widget ctx idx + 1
		text: gtk_combo_box_text_get_active_text widget
		set-text widget ctx text
		if res = EVT_DISPATCH [
			make-event widget idx + 1 EVT_CHANGE
		]
	]
]

text-list-selected-rows-changed: func [
	[cdecl]
	widget	[handle!]
	ctx		[node!]
	/local
		idx [integer!]
		sel [handle!]
		res [integer!]
		text [c-string!]
][
	; From now, only single-selection mode
	sel: gtk_list_box_get_selected_row widget
	idx: either null? sel [-1][gtk_list_box_row_get_index sel]
	if idx >= 0 [
		res: make-event widget idx + 1 EVT_SELECT
		set-selected widget ctx idx + 1
		text: gtk_label_get_text gtk_bin_get_child sel
		set-text widget ctx text
		if res = EVT_DISPATCH [
			make-event widget idx + 1 EVT_CHANGE
		]
	]
]

tab-panel-switch-page: func [
	[cdecl]
	widget	[handle!]
	page	[handle!]
	idx		[integer!]
	ctx		[node!]
	/local
		res  [integer!]
		text [c-string!]
][
	if idx >= 0 [
		res: make-event widget idx + 1 EVT_SELECT
		set-selected widget ctx idx + 1
		text: gtk_notebook_get_tab_label_text widget page
		set-text widget ctx text
		if res = EVT_DISPATCH [
			make-event widget idx + 1 EVT_CHANGE
		]
	]
]

; Do not use key-press-event since character would not be printed!
field-key-release-event: func [
	[cdecl]
	widget		[handle!]
	event-key	[GdkEventKey!]
	ctx			[node!]
	/local
		res		[integer!]
		key		[integer!]
		flags	[integer!]
][
	;print "key-release: "
	;print [ "keyval: " event-key/keyval  " -> " gdk_keyval_name event-key/keyval  "(" event-key/keyval  " -> " gdk_keyval_to_lower event-key/keyval ") et state: " event-key/state lf]
	;print [ "keycode: " as integer! event-key/keycode1 " " as integer! event-key/keycode2 lf]

	if event-key/keyval > FFFFh [exit]
	key: translate-key event-key/keyval
	flags: 0 ;either char-key? as-byte key [0][80000000h]	;-- special key or not
	flags: flags or check-extra-keys event-key/state

	print ["key: " key " flags: " flags " key or flags: " key or flags lf]

	res: make-event widget key or flags EVT_KEY_DOWN
	if res <> EVT_NO_DISPATCH [
	; 	either flags and 80000000h <> 0 [				;-- special key
	; 		make-event widget key or flags EVT_KEY
	; 	][
	; 		if key = 8 [								;-- backspace
	 			make-event widget key or flags EVT_KEY
	; 			exit
	; 		]
	; 		key: objc_msgSend [event sel_getUid "characters"]
	; 		if all [
	; 			key <> 0
	; 			0 < objc_msgSend [key sel_getUid "length"]
	; 		][
	; 			key: objc_msgSend [key sel_getUid "characterAtIndex:" 0]
	; 			make-event widget key or flags EVT_KEY
	; 		]
	; 	]
	]
]

field-move-focus: func [
	[cdecl]
	widget	[handle!]
	event	[handle!]
	ctx		[node!] 
][
	print-line "move-focus"
]

field-size-allocate: func [
	[cdecl]
	widget	[handle!]
	event	[handle!]
	ctx		[node!] 
	/local
		rect [RECT_STRUCT]
][
	print-line "size-allocate"
	rect: as RECT_STRUCT event
	print [" rect:" rect/left "x" rect/top  "x" rect/right "x" rect/bottom lf]
]

area-changed: func [
	[cdecl]
	buffer	[handle!]
	widget	[handle!]
	/local
		text	[c-string!]
		face	[red-object!]
		qdata	[handle!]
		start	[GtkTextIter!]
		end		[GtkTextIter!]
][
	start: as GtkTextIter! allocate (size? GtkTextIter!) 
	end: as GtkTextIter! allocate (size? GtkTextIter!) 
	gtk_text_buffer_get_bounds buffer as handle! start as handle! end
	text: gtk_text_buffer_get_text buffer as handle! start as handle! end no
	free as byte-ptr! start free as byte-ptr! end 
	qdata: g_object_get_qdata widget red-face-id
    if qdata <> as handle! 0 [
        face: as red-object! qdata
		set-text widget face/ctx text
		make-event widget 0 EVT_CHANGE
	]
]
