" File: repeatable-motions.vim
" Author: Mohammed Chelouti <mhc23 at web dot de>
" Description: Plugin that makes many motions repeatable
" Last Modified: Jul 26, 2014

if exists('g:loaded_repeatable_motions') || !has('eval')
    finish
endif
if !exists('g:repeatable_motions_use_default_mappings')
    let g:repeatable_motions_use_default_mappings = 1
endif
let g:loaded_repeatable_motions = 1

let s:repeatable_motions = []
let s:previous_columnwise_motion = ''
let s:previous_linewise_motion = ''
let s:most_recent_motion = ''

let s:tf_target = ''
let s:repeating = 0
let g:linewise_motion_repeating = 0
let g:columnwise_motion_repeating = 0

" horizontal start = -1
" horizontal end = 1
"
" vertical start = -2
" vertical end = 2
function! s:RepeatMotion(...)
    if (a:0 > 0)
        let direction = a:1
    else
        let direction = s:GetMotionDirection(s:most_recent_motion)
    endif

    let result = col('.').'|'
    if direction % 2 == 0
        let motionObject = s:GetMotionObject(s:previous_linewise_motion)
    else
        let motionObject = s:GetMotionObject(s:previous_columnwise_motion)
    endif

    if type(motionObject) != type({})
        return result
    endif

    let s:repeating = 1
    if direction % 2 == 0
        let g:linewise_motion_repeating = direction / 2
    else
        let g:columnwise_motion_repeating = direction
    endif

    if direction > 0
        let result = s:Move(motionObject.forwards.lhs)
    elseif direction < 0
        let result = s:Move(motionObject.backwards.lhs)
    endif

    let g:linewise_motion_repeating = 0
    let g:columnwise_motion_repeating = 0
    let s:repeating = 0

    return result
endfunction

function! s:Move(motion)
    let direction = s:GetMotionDirection(a:motion)
    let motionObject = s:GetMotionObject(a:motion)

    if type(motionObject) == type({})
        if motionObject.linewise
            let s:previous_linewise_motion = s:NormalizeMotion(a:motion)
        else
            let s:previous_columnwise_motion = s:NormalizeMotion(a:motion)
        endif

        let s:most_recent_motion = s:NormalizeMotion(a:motion)

        if direction > 0
            let directionKey = 'forwards'
        else
            let directionKey = 'backwards'
        endif

        if motionObject[directionKey].expr
            return eval(motionObject[directionKey].rhs)
        else
            let keys = s:MakeKeysFeedable(motionObject[directionKey].rhs)
            return keys
        endif

    endif
endfunction

function! s:MakeKeysFeedable(keystrokes)
    let m = escape(a:keystrokes, '\')
    let m = escape(m, '"')
    let specialChars = [
                \ "<BS>",      "<Tab>",     "<FF>",         "<t_",
                \ "<CR>",      "<Return>",  "<Enter>",      "<Esc>",
                \ "<Space>",   "<lt>",      "<Bslash>",     "<Bar>",
                \ "<Del>",     "<CSI>",     "<xCSI>",       "<EOL>",
                \ "<Up>",      "<Down>",    "<Left>",       "<Right>",
                \ "<F",        "<Help>",    "<Undo>",       "<Insert>",
                \ "<Home>",    "<End>",     "<PageUp>",     "<PageDown>",
                \ "<kHome>",   "<kEnd>",    "<kPageUp>",    "<kPageDown>",
                \ "<kPlus>",   "<kMinus>",  "<kMultiply>",  "<kDivide>",
                \ "<kEnter>",  "<kPoint>",  "<k0>",         "<S-",
                \ "<C-",       "<M-",       "<A-",          "<D-"
                \]
    for s in specialChars
        let m = substitute(m, '\('.s.'\)', '\\\1', 'g')
    endfor

    silent exe 'return "'.m.'"'
endfunction

" backwards: {lhs} of the mapping to move the cursor backwards
" forwards: {lhs} of the mapping to move the cursor forwards
" linewise: if 1 the motion will be repeated vertically, otherwise horizontally
function! AddRepeatableMotion(backwards, forwards, linewise)
    let motionPair = { 'linewise': a:linewise }
    let defaultMaparg = { 'mode': '', 'noremap': 1, 'buffer': 0, 'silent': 0, 'expr': 0, 'nowait': 0 }
    let buffer = 0
    let mapstring = 'noremap <expr>'

    let maparg = maparg(a:backwards, '', 0, 1)
    if !empty(maparg)
        let motionPair.backwards = maparg
        if maparg.buffer
            let mapstring .= ' <buffer>'
        endif

        if maparg.silent
            let mapstring .= ' <silent>'
        endif
    else
        let motionPair.backwards = deepcopy(defaultMaparg)
        let motionPair.backwards.lhs = a:backwards
        let motionPair.backwards.rhs = a:backwards
    endif

    let maparg = maparg(a:forwards, '', 0, 1)
    if !empty(maparg)
        let motionPair.forwards = maparg
    else
        let motionPair.forwards = deepcopy(defaultMaparg)
        let motionPair.forwards.lhs = a:forwards
        let motionPair.forwards.rhs = a:forwards
    endif

    exe mapstring a:backwards '<SID>Move('''.a:backwards.''')'
    exe mapstring a:forwards '<SID>Move('''.a:forwards.''')'

    let targetList = s:repeatable_motions

    if motionPair.backwards.buffer || motionPair.forwards.buffer
        if !motionPair.backwards.buffer || !motionPair.forwards.buffer
            echoerr motionPair.backwards.lhs 'and' motionPair.forwards 'must be buffer or global mappings'
            return
        endif
        let targetList = b:repeatable_motions
    endif

    for m in targetList
        if m.backwards.lhs ==# a:backwards || m.forwards.lhs ==# a:forwards
            echoerr ''''.m.backwards.lhs ':' m.forwards.lhs.''' already defined'
            return
        endif
    endfor

    call add(targetList, motionPair)
endfunction

function! RemoveRepeatableMotion(motion)
    let motion = s:NormalizeMotion(a:motion)
    let motion = substitute(motion, '<Leader>', g:mapleader, 'g')
    let object = s:GetMotionObject(motion)
    let lists = [s:repeatable_motions]

    if type(object) != type({})
        return
    endif

    if exists('b:repeatable_motions')
        call insert(lists, b:repeatable_motions)
    endif

    for l in lists
        let i = 0
        for m in l
            if m.backwards.lhs == object.backwards.lhs
                for dir in ['backwards', 'forwards']

                    if m[dir].lhs ==# m[dir].rhs
                        if m[dir].buffer
                            exe 'bufdo unmap <buffer>' m[dir].lhs
                        else
                            exe 'unmap' m[dir].lhs
                        endif

                    else
                        if m[dir].noremap
                            let mapString = 'noremap'
                        else
                            let mapString = 'map'
                        endif

                        if m[dir].buffer
                            let mapString .= ' <buffer>'
                        endif

                        if m[dir].silent
                            let mapString .= ' <silent>'
                        endif

                        if m[dir].expr
                            let mapString .= ' <expr>'
                        endif
                    endif

                endfor

                call remove(l, i)
                break
            endif
            let i += 1
        endfor
    endfor
endfunction

function! s:GetMotionObject(motion)
    let lists = [s:repeatable_motions]
    if exists('b:repeatable_motions')
        call insert(lists, b:repeatable_motions)
    endif

    for l in lists
        for m in l
            if s:NormalizeMotion(m.backwards.lhs) ==# s:NormalizeMotion(a:motion)
                        \ || s:NormalizeMotion(m.forwards.lhs) ==# s:NormalizeMotion(a:motion)
                return m
            endif
        endfor
    endfor
endfunction

function! s:IsBufferMotion(motionObject)
    return motionObject.backwards.buffer
endfunction

function! GetPreviouslyPerformedMotion(linewise)
    if a:linewise
        let motionObject = s:GetMotionObject(s:previous_linewise_motion)
    else
        let motionObject = s:GetMotionObject(s:previous_columnwise_motion)
    endif

    if type(motionObject) != type({})
        unlet! motionObject
        let motionObject = {}
    endif

    return motionObject
endfunction

function! s:ListMotions()
    let linewiseMotions = []
    let columnwiseMotions = []
    for l in [s:repeatable_motions, b:repeatable_motions]
        for m in l
            let text = ''

            if l == b:repeatable_motions
                let text = '<buffer> '
            endif

            let text .= m.backwards.lhs

            let text .= ' : '.m.forwards.lhs

            if m.linewise
                if m.backwards.lhs ==# s:previous_linewise_motion || m.forwards.lhs ==# s:previous_linewise_motion
                    let text = '* '.text
                endif
                call add(linewiseMotions, "  " . text)
            else
                if m.backwards.lhs ==# s:previous_columnwise_motion || m.forwards.lhs ==# s:previous_columnwise_motion
                    let text = '* '.text
                endif
                call add(columnwiseMotions, "  " . text)
            endif
        endfor
    endfor

    unlet! m

    echo "Linewise motions"
    if empty(linewiseMotions)
        echo "  no repeatable linewise motions"
    else
        for m in linewiseMotions
            echo m
        endfor
    endif

    echo "Columnwise motions"
    if empty(columnwiseMotions)
        echo "  no repeatable columnwise motions"
    else
        for m in columnwiseMotions
            echo m
        endfor
    endif
endfunction

" 0: Motion not declared
" -1: columnwise backwards
" 1: columnwise forwards
" -2: linewise backwards
" 2: linewise forwards
function! s:GetMotionDirection(motion)
    let motionObject = s:GetMotionObject(a:motion)

    if type(motionObject) != type({})
        return 0
    elseif s:NormalizeMotion(a:motion) ==# s:NormalizeMotion(motionObject.backwards.lhs)
        let dir = -1
    else
        let dir = 1
    endif

    if motionObject.linewise
        return dir * 2
    else
        return dir
    endif
endfunction

" t/T and f/F are special motions and need this workaround to be easily repeatable
function! s:TFWorkaround(motion)
    if !g:columnwise_motion_repeating
        let s:tf_target = nr2char(getchar())
        let s:tf_motion = a:motion
        return a:motion . s:tf_target
    else
        return (s:tf_motion ==# a:motion) ? ';' : ','
    endif
endfunction

function! s:NormalizeMotion(motion)
    let result = substitute(a:motion, '<\ze[^>]\+>', '\\<', 'g')
    exe 'return "'. result . '"'
endfunction

if !exists('g:tf_workaround')
    let g:tf_workaround = 1
endif

let s:default_mappings = [
            \ {'bwd': '{', 'fwd': '}', 'linewise': 1},
            \ {'bwd': '[[', 'fwd': ']]', 'linewise': 1},
            \ {'bwd': '[c', 'fwd': ']c', 'linewise': 1},
            \ {'bwd': '[m', 'fwd': ']m', 'linewise': 1},
            \ {'bwd': '[M', 'fwd': ']M', 'linewise': 1},
            \ {'bwd': '[*', 'fwd': ']*', 'linewise': 1},
            \ {'bwd': '[/', 'fwd': ']/', 'linewise': 1},
            \ {'bwd': '[]', 'fwd': '][', 'linewise': 1},
            \ {'bwd': '[''', 'fwd': ']''', 'linewise': 1},
            \ {'bwd': '[`', 'fwd': ']`', 'linewise': 1},
            \ {'bwd': '[(', 'fwd': '])', 'linewise': 1},
            \ {'bwd': '[{', 'fwd': ']}', 'linewise': 1},
            \ {'bwd': '[#', 'fwd': ']#', 'linewise': 1},
            \ {'bwd': '[z', 'fwd': ']z', 'linewise': 1},
            \ {'bwd': 'zk', 'fwd': 'zj', 'linewise': 1},
            \ {'bwd': '(', 'fwd': ')', 'linewise': 0},
            \ {'bwd': '[s', 'fwd': ']s', 'linewise': 0}
            \ ]

command ListRepeatableMotions call <SID>ListMotions()

noremap <script> <expr> <silent> <Plug>RepeatMotionUp <SID>RepeatMotion(-2)
noremap <script> <expr> <silent> <Plug>RepeatMotionDown <SID>RepeatMotion(2)
noremap <script> <expr> <silent> <Plug>RepeatMotionLeft <SID>RepeatMotion(-1)
noremap <script> <expr> <silent> <Plug>RepeatMotionRight <SID>RepeatMotion(1)
noremap <script> <expr> <silent> <Plug>RepeatMostRecentMotion <SID>RepeatMotion()

if g:tf_workaround
    noremap <script> <expr> <silent> t <SID>TFWorkaround('t')
    noremap <script> <expr> <silent> T <SID>TFWorkaround('T')
    noremap <script> <expr> <silent> f <SID>TFWorkaround('f')
    noremap <script> <expr> <silent> F <SID>TFWorkaround('F')

    call add(s:default_mappings, {'bwd': 'F', 'fwd': 'f', 'linewise': 0})
    call add(s:default_mappings, {'bwd': 'T', 'fwd': 't', 'linewise': 0})
endif

for m in s:default_mappings
    call AddRepeatableMotion(m.bwd, m.fwd, m.linewise)
endfor

autocmd BufReadPost *
            \ let b:repeatable_motions = [] |
            \ for m in s:repeatable_motions |
            \   let bmapargs = maparg(m.backwards.lhs, '', 0, 1) |
            \   let fmapargs = maparg(m.forwards.lhs, '', 0, 1) |
            \   if bmapargs.buffer || fmapargs.buffer |
            \      call AddRepeatableMotion(m.backwards.lhs, m.forwards.lhs, m.linewise) |
            \   endif |
            \ endfor |
