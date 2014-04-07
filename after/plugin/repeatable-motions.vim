for m in [{'plugMapping': 'RepeatMotionUp', 'defaultMapping': '<C-k>'}, { 'plugMapping': 'RepeatMotionDown', 'defaultMapping': '<C-j>'}, { 'plugMapping': 'RepeatMotionLeft', 'defaultMapping': '<C-h>'}, { 'plugMapping': 'RepeatMotionRight', 'defaultMapping': '<C-l>' }]
    if !hasmapto("<Plug>". m.plugMapping, '')
        exe "map" m.defaultMapping "<Plug>" . m.plugMapping
    endif
endfor
