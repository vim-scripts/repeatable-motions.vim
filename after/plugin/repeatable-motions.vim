if (exists('g:repeatable_motions_use_default_mappings') && !g:repeatable_motions_use_default_mappings)
    finish
endif

for m in [{'plugMapping': 'RepeatMotionUp', 'defaultMapping': '<C-k>'}, { 'plugMapping': 'RepeatMotionDown', 'defaultMapping': '<C-j>'}, { 'plugMapping': 'RepeatMotionLeft', 'defaultMapping': '<C-h>'}, { 'plugMapping': 'RepeatMotionRight', 'defaultMapping': '<C-l>' }, {'plugMapping': 'RepeatMostRecentMotion', 'defaultMapping': 'g.' }]
    if !hasmapto("<Plug>". m.plugMapping, '')
        exe "map" m.defaultMapping "<Plug>" . m.plugMapping
    endif
endfor
