##############################################################################
#
#    CoCalc: Collaborative Calculation in the Cloud
#
#    Copyright (C) 2016, Sagemath Inc.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

# standard non-CoCalc libraries
immutable = require('immutable')
{IS_MOBILE, IS_TOUCH, isMobile} = require('./feature')
underscore = require('underscore')

# CoCalc libraries
{Avatar} = require('./other-users')
misc = require('smc-util/misc')
misc_page = require('./misc_page')
{defaults, required} = misc

# React libraries
{React, ReactDOM, rclass, rtypes, Actions, Store}  = require('./smc-react')
{Icon, Loading, Markdown, SearchInput, TimeAgo, Tip} = require('./r_misc')
{Alert, Button, Col, Grid, FormGroup, FormControl, ListGroup, ListGroupItem, Row, ButtonGroup, Well} = require('react-bootstrap')

{User} = require('./users')

editor_chat = require('./editor_chat')

{redux_name, init_redux, remove_redux, newest_content, sender_is_viewer, show_user_name, is_editing, blank_column, render_markdown, render_history_title, render_history_footer, render_history, get_user_name, send_chat, clear_input, is_at_bottom, scroll_to_bottom, scroll_to_position} = require('./editor_chat')

{VideoChatButton} = require('./video-chat')
{SMC_Dropwrapper} = require('./smc-dropzone')

Message = rclass
    displayName: 'Message'

    propTypes:
        actions        : rtypes.object

        focus_end      : rtypes.func
        get_user_name  : rtypes.func

        message        : rtypes.immutable.Map.isRequired  # immutable.js message object
        history        : rtypes.immutable.List
        account_id     : rtypes.string.isRequired
        date           : rtypes.string
        sender_name    : rtypes.string
        editor_name    : rtypes.string
        user_map       : rtypes.immutable.Map
        project_id     : rtypes.string    # optional -- improves relative links if given
        file_path      : rtypes.string    # optional -- (used by renderer; path containing the chat log)
        font_size      : rtypes.number
        show_avatar    : rtypes.bool
        is_prev_sender : rtypes.bool
        is_next_sender : rtypes.bool
        show_heads     : rtypes.bool
        saved_mesg     : rtypes.string

    getInitialState: ->
        edited_message : newest_content(@props.message)
        history_size   : @props.message.get('history').size
        show_history   : false
        new_changes    : false

    shouldComponentUpdate: (next, next_state) ->
        return misc.is_different(@props, next, ['message', 'user_map', 'account_id', 'show_avatar', \
                   'is_prev_sender', 'is_next_sender', 'editor_name', 'saved_mesg', 'sender_name']) or \
               misc.is_different(@state, next_state, ['edited_message', 'show_history', 'new_changes'])

    componentWillReceiveProps: (newProps) ->
        if @state.history_size != @props.message.get('history').size
            @setState(history_size:@props.message.get('history').size)
        changes = false
        if @state.edited_message == newest_content(@props.message)
            @setState(edited_message : newProps.message.get('history')?.first()?.get('content') ? '')
        else
            changes = true
        @setState(new_changes : changes)

    componentDidMount: ->
        if @refs.editedMessage
            @setState(edited_message:@props.saved_mesg)

    componentDidUpdate: ->
        if @refs.editedMessage
            @props.actions.saved_message(ReactDOM.findDOMNode(@refs.editedMessage).value)

    toggle_history: ->
        # No history for mobile, since right now messages in mobile are too clunky
        if not IS_MOBILE
            if not @state.show_history
                <span className="small" style={marginLeft:'10px', cursor:'pointer'} onClick={=>@toggle_history_chat(true)}>
                    <Tip title='Message History' tip='Show history of editing of this message.'>
                        <Icon name='history'/> Edited
                    </Tip>
                </span>
            else
                <span className="small"
                     style={marginLeft:'10px', cursor:'pointer'}
                     onClick={=>@toggle_history_chat(false)} >
                    <Tip title='Message History' tip='Hide history of editing of this message.'>
                        <Icon name='history'/> Hide History
                    </Tip>
                </span>

    toggle_history_chat: (bool) ->
        @setState(show_history:bool)
        @props.set_scroll()

    editing_status: ->
        other_editors = @props.message.get('editing').remove(@props.account_id).keySeq()
        current_user = @props.user_map.get(@props.account_id).get('first_name') + ' ' + @props.user_map.get(@props.account_id).get('last_name')
        if is_editing(@props.message, @props.account_id)
            if other_editors.size == 1
                # This user and someone else is also editing
                text = "#{@props.get_user_name(other_editors.first())} is also editing this!"
                color = "#E55435"
            else if other_editors.size > 1
                # Multiple other editors
                text = "#{other_editors.size} other users are also editing this!"
                color = "#E55435"
            else if @state.history_size != @props.message.get('history').size and @state.new_changes
                text = "#{@props.editor_name} has updated this message. Esc to discard your changes and see theirs"
                color = "#E55435"
            else
                if IS_TOUCH
                    text = "You are now editing ..."
                else
                    text = "You are now editing ... Shift+Enter to submit changes."
        else
            if other_editors.size == 1
                # One person is editing
                text = "#{@props.get_user_name(other_editors.first())} is editing this message"
            else if other_editors.size > 1
                # Multiple editors
                text = "#{other_editors.size} people are editing this message"
            else if newest_content(@props.message).trim() == ''
                text = "Deleted by #{@props.editor_name}"

        text ?= "Last edit by #{@props.editor_name}"

        if not is_editing(@props.message, @props.account_id) and other_editors.size == 0 and newest_content(@props.message).trim() != ''
            edit = "Last edit "
            name = " by #{@props.editor_name}"
            <span className="small">
                {edit}
                <TimeAgo date={new Date(@props.message.get('history').first()?.get('date'))} />
                {name}
            </span>
        else
            <span className="small">
                {text}
                {<Button onClick={@save_edit} bsStyle='success' style={marginLeft:'10px',marginTop:'-5px'} className='small'>Save</Button> if is_editing(@props.message, @props.account_id)}
            </span>

    edit_message: ->
        @props.actions.set_editing(@props.message, true)

    on_keydown: (e) ->
        if e.keyCode==27 # ESC
            e.preventDefault()
            @setState
                edited_message : newest_content(@props.message)
            @props.actions.set_editing(@props.message, false)
        else if e.keyCode==13 and e.shiftKey # 13: enter key
            mesg = ReactDOM.findDOMNode(@refs.editedMessage).value
            if mesg != newest_content(@props.message)
                @props.actions.send_edit(@props.message, mesg)
            else
                @props.actions.set_editing(@props.message, false)

    save_edit: ->
        mesg = ReactDOM.findDOMNode(@refs.editedMessage).value
        if mesg != newest_content(@props.message)
            @props.actions.send_edit(@props.message, mesg)
        else
            @props.actions.set_editing(@props.message, false)

    # All the columns
    avatar_column: ->
        account = @props.user_map?.get(@props.message.get('sender_id'))?.toJS()
        if @props.is_prev_sender
            margin_top = '5px'
        else
            margin_top = '15px'

        if sender_is_viewer(@props.account_id, @props.message)
            textAlign = 'left'
            marginRight = '11px'
        else
            textAlign = 'right'
            marginLeft = '11px'

        style =
            display       : "inline-block"
            marginTop     : margin_top
            marginLeft    : marginLeft
            marginRight   : marginRight
            padding       : '0px'
            textAlign     : textAlign
            verticalAlign : "middle"
            width         : '4%'

        # TODO: do something better when we don't know the user (or when sender account_id is bogus)
        <Col key={0} xsHidden={true} sm={1} style={style} >
            <div>
                {<Avatar size={32} account_id={account.account_id} /> if account? and @props.show_avatar}
            </div>
        </Col>

    content_column: ->
        value = newest_content(@props.message)

        {background, color, lighten, message_class} = editor_chat.message_colors(@props.account_id, @props.message)

        # smileys, just for fun.
        value = misc.smiley
            s    : value
            wrap : ['<span class="smc-editor-chat-smiley">', '</span>']

        font_size = "#{@props.font_size}px"

        if @props.show_avatar
            marginBottom = "1vh"
        else
            marginBottom = "3px"

        if not @props.is_prev_sender and sender_is_viewer(@props.account_id, @props.message)
            marginTop = "17px"

        if not @props.is_prev_sender and not @props.is_next_sender and not @state.show_history
            borderRadius = '10px 10px 10px 10px'
        else if not @props.is_prev_sender
            borderRadius = '10px 10px 5px 5px'
        else if not @props.is_next_sender
            borderRadius = '5px 5px 10px 10px'

        message_style =
            color        : color
            background   : background
            wordWrap     : "break-word"
            marginBottom : "3px"
            marginTop    : marginTop
            borderRadius : borderRadius
            fontSize     : font_size

        <Col key={1} xs={10} sm={9}>
            {show_user_name(@props.sender_name) if not @props.is_prev_sender and not sender_is_viewer(@props.account_id, @props.message)}
            <Well style={message_style} className="smc-chat-message" bsSize="small" onDoubleClick = {@edit_message}>
                <span style={lighten}>
                    {editor_chat.render_timeago(@props.message, @edit_message)}
                </span>
                {render_markdown(value, @props.project_id, @props.file_path, message_class) if not is_editing(@props.message, @props.account_id)}
                {@render_input()   if is_editing(@props.message, @props.account_id)}
                <span style={lighten}>
                    {@editing_status() if @props.message.get('history').size > 1 or  @props.message.get('editing').size > 0}
                    {@toggle_history() if @props.message.get('history').size > 1}
                </span>
            </Well>
            {render_history_title() if @state.show_history}
            {render_history(@props.history, @props.user_map) if @state.show_history}
            {render_history_footer() if @state.show_history}
        </Col>

    # All the render methods

    render_input: ->
        <div>
            <FormGroup>
                <FormControl
                    style     = {fontSize:@props.font_size}
                    autoFocus = {true}
                    rows      = {4}
                    componentClass = 'textarea'
                    ref       = 'editedMessage'
                    onKeyDown = {@on_keydown}
                    value     = {@state.edited_message}
                    onChange  = {(e)=>@setState(edited_message: e.target.value)}
                    onFocus   = {@props.focus_end}
                />
            </FormGroup>
        </div>

    render: ->
        if @props.include_avatar_col
            cols = [@avatar_column(), @content_column(), blank_column()]
            # mirror right-left for sender's view
            if sender_is_viewer(@props.account_id, @props.message)
                cols = cols.reverse()
            <Row>
                {cols}
            </Row>
        else
            cols = [@content_column(), blank_column()]
            # mirror right-left for sender's view
            if sender_is_viewer(@props.account_id, @props.message)
                cols = cols.reverse()
            <Row>
                {cols}
            </Row>

SCROLL_DEBOUNCE_MS = 750

ChatLog = rclass
    displayName: "ChatLog"

    propTypes:
        messages     : rtypes.object.isRequired   # immutable js map {timestamps} --> message.
        user_map     : rtypes.object              # immutable js map {collaborators} --> account info
        account_id   : rtypes.string
        project_id   : rtypes.string   # optional -- used to render links more effectively
        file_path    : rtypes.string   # optional -- ...
        font_size    : rtypes.number
        actions      : rtypes.object
        show_heads   : rtypes.bool
        focus_end    : rtypes.func
        saved_mesg   : rtypes.string
        set_scroll   : rtypes.func
        search       : rtypes.string

    shouldComponentUpdate: (next) ->
        return @props.messages != next.messages or
               @props.search != next.search or
               @props.user_map != next.user_map or
               @props.account_id != next.account_id or
               @props.saved_mesg != next.saved_mesg

    get_user_name: (account_id) ->
        account = @props.user_map?.get(account_id)
        if account?
            account_name = account.get('first_name') + ' ' + account.get('last_name')
        else
            account_name = "Unknown"

    list_messages: ->
        is_next_message_sender = (index, dates, messages) ->
            if index + 1 == dates.length
                return false
            current_message = messages.get(dates[index])
            next_message = messages.get(dates[index + 1])
            return current_message.get('sender_id') == next_message.get('sender_id')

        is_prev_message_sender = (index, dates, messages) ->
            if index == 0
                return false
            current_message = messages.get(dates[index])
            prev_message = messages.get(dates[index - 1])
            return current_message.get('sender_id') == prev_message.get('sender_id')

        sorted_dates = @props.messages.keySeq().sort().toJS()
        v = []
        if @props.search
            search_terms = misc.search_split(@props.search.toLowerCase())
        else
            search_terms = undefined

        not_showing = 0
        for date, i in sorted_dates
            message = @props.messages.get(date)
            first = message?.get('history').first()
            last_editor_name = @get_user_name(first?.get('author_id'))
            sender_name = @get_user_name(message?.get('sender_id'))
            if search_terms?
                content = first?.get('content') + ' ' + last_editor_name + ' ' + sender_name
                content = content.toLowerCase()
                if not misc.search_match(content, search_terms)
                    not_showing += 1
                    continue

            v.push <Message key={date}
                     account_id       = {@props.account_id}
                     history          = {message.get('history')}
                     user_map         = {@props.user_map}
                     message          = {message}
                     date             = {date}
                     project_id       = {@props.project_id}
                     file_path        = {@props.file_path}
                     font_size        = {@props.font_size}
                     is_prev_sender   = {is_prev_message_sender(i, sorted_dates, @props.messages)}
                     is_next_sender   = {is_next_message_sender(i, sorted_dates, @props.messages)}
                     show_avatar      = {@props.show_heads and not is_next_message_sender(i, sorted_dates, @props.messages)}
                     include_avatar_col = {@props.show_heads}
                     get_user_name    = {@get_user_name}
                     sender_name      = {sender_name}
                     editor_name      = {last_editor_name}
                     actions          = {@props.actions}
                     focus_end        = {@props.focus_end}
                     saved_mesg       = {if message.getIn(['editing', @props.account_id]) then @props.saved_mesg}
                     set_scroll       = {@props.set_scroll}
                    />

        if not_showing
            s = <Alert bsStyle='warning' key='not_showing'>Hiding {not_showing} chats that do not match search for '{@props.search}'.</Alert>
            v.push(s)

        return v

    render: ->
        <Grid fluid>
            {@list_messages()}
        </Grid>

exports.ChatRoom = rclass ({name}) ->
    displayName: "ChatRoom"

    reduxProps :
        "#{name}" :
            height             : rtypes.number
            input              : rtypes.string
            is_preview         : rtypes.bool
            messages           : rtypes.immutable
            offset             : rtypes.number
            saved_mesg         : rtypes.string
            saved_position     : rtypes.number
            use_saved_position : rtypes.bool
            search             : rtypes.string

        users :
            user_map : rtypes.immutable

        account :
            account_id : rtypes.string
            font_size  : rtypes.number

        file_use :
            file_use : rtypes.immutable

    propTypes :
        redux           : rtypes.object
        actions         : rtypes.object
        name            : rtypes.string.isRequired
        project_id      : rtypes.string.isRequired
        path            : rtypes.string

    getDefaultProps: ->
        input : ''

    getInitialState: ->
        preview : ''

    preview_style:
        background   : '#f5f5f5'
        fontSize     : '14px'
        borderRadius : '10px 10px 10px 10px'
        boxShadow    : '#666 3px 3px 3px'
        paddingBottom: '20px'

    componentWillMount: ->
        for f in ['set_preview_state', 'set_chat_log_state', 'debounce_bottom', 'mark_as_read']
            @[f] = underscore.debounce(@[f], 300)

    fix_scroll_position_after_mount: ->
        # Optionally set the scroll position back after waiting a moment
        # for image sizes to load.
        fix_pos = =>
            if not @_is_mounted
                return
            scroll_to_position(@refs.log_container, @props.saved_position, @props.offset,
                               @props.height, @props.use_saved_position, @props.actions)
        # We adjust the scroll position multiple times due to dynamic content (e.g., images)
        # changing the vertical height as the chat history is rendered.  This can fail
        # if the dynamic change takes a while, but the failure is a slight scroll position
        # issue -- if the user is switching tabs back and forth in a session, that is very
        # unlikely, due to the browser caching the dynamic content.
        # The user is also unlikely to manually scroll the page then see it jump to
        # this fixed position within 500ms of mounting.
        for tm in [0, 200, SCROLL_DEBOUNCE_MS-250]
            setTimeout(fix_pos, tm)

    componentDidMount: ->
        @_is_mounted = true
        @fix_scroll_position_after_mount()
        if @props.is_preview
            if is_at_bottom(@props_saved_position, @props.offest, @props.height)
                @debounce_bottom()
        else
            @props.actions.set_is_preview(false)

    componentWillReceiveProps: (next) ->
        if (@props.messages != next.messages or @props.input != next.input) and is_at_bottom(@props.saved_position, @props.offset, @props.height)
            @props.actions.set_use_saved_position(false)

    componentDidUpdate: ->
        if not @props.use_saved_position
            scroll_to_bottom(@refs.log_container, @props.actions)

    mark_as_read: ->
        info = @props.redux.getStore('file_use').get_file_info(@props.project_id, @props.path)
        if not info? or info.is_unread  # file is unread from *our* point of view, so mark read
            @props.redux.getActions('file_use').mark_file(@props.project_id, @props.path, 'read', 2000)

    keydown: (e) ->
        # TODO: Add timeout component to is_typing
        if e.keyCode==13 and e.shiftKey # 13: enter key
            send_chat(e, @refs.log_container, ReactDOM.findDOMNode(@refs.input).value, @props.actions)
        else if e.keyCode==38 and ReactDOM.findDOMNode(@refs.input).value == ''
            # Up arrow on an empty input
            @props.actions.set_to_last_input()

    componentWillUnmount: ->
        @_is_mounted = false
        @save_scroll_position()

    save_scroll_position: ->
        @props.actions.set_use_saved_position(true)
        node = ReactDOM.findDOMNode(@refs.log_container)
        if node?
            @props.actions.save_scroll_state(node.scrollTop, node.scrollHeight, node.offsetHeight)

    button_send_chat: (e) ->
        send_chat(e, @refs.log_container, ReactDOM.findDOMNode(@refs.input).value, @props.actions)
        ReactDOM.findDOMNode(@refs.input).focus()

    button_scroll_to_bottom: ->
        scroll_to_bottom(@refs.log_container, @props.actions)

    button_off_click: ->
        @props.actions.set_is_preview(false)
        ReactDOM.findDOMNode(@refs.input).focus()

    button_on_click: ->
        @props.actions.set_is_preview(true)
        ReactDOM.findDOMNode(@refs.input).focus()
        if is_at_bottom(@props.saved_position, @props.offset, @props.height)
            scroll_to_bottom(@refs.log_container, @props.actions)

    set_chat_log_state: ->
        if @refs.log_container?
            node = ReactDOM.findDOMNode(@refs.log_container)
            @props.actions.save_scroll_state(node.scrollTop, node.scrollHeight, node.offsetHeight)

    set_preview_state: ->
        if @refs.log_container?
            @setState(preview:@props.input)
        if @refs.preview
            node = ReactDOM.findDOMNode(@refs.preview)
            @_preview_height = node.offsetHeight - 12 # sets it to 75px starting then scales with height.

    debounce_bottom: ->
        #debounces it so that the preview shows up then calls
        scroll_to_bottom(@refs.log_container, @props.actions)

    show_files: ->
        @props.redux?.getProjectActions(@props.project_id).load_target('files')

    show_timetravel: ->
        @props.redux?.getProjectActions(@props.project_id).open_file
            path               : misc.history_path(@props.path)
            foreground         : true
            foreground_project : true

    # All render methods
    render_bottom_tip: ->
        tip = <span>
            You may enter (Github flavored) markdown here and include Latex mathematics in $ signs.  In particular, use # for headings, > for block quotes, *'s for italic text, **'s for bold text, - at the beginning of a line for lists, back ticks ` for code, and URL's will automatically become links.   Press shift+enter to send your chat. Double click to edit past chats.
        </span>

        <Tip title='Use Markdown' tip={tip}>
            <div style={color: '#767676', fontSize: '12.5px', marginBottom:'5px'}>
                Shift+Enter to send your message.
                Double click chat bubbles to edit them.
                Format using <a href='https://help.github.com/articles/getting-started-with-writing-and-formatting-on-github/' target='_blank'>Markdown</a> and <a href="https://en.wikibooks.org/wiki/LaTeX/Mathematics" target='_blank'>LaTeX</a>.
                Emoticons: {misc.emoticons}.
            </div>
        </Tip>

    render_preview_message: ->
        @set_preview_state()
        if @state.preview.length > 0
            value = @state.preview
            value = misc.smiley
                s: value
                wrap: ['<span class="smc-editor-chat-smiley">', '</span>']
            value = misc_page.sanitize_html_safe(value)
            file_path = if @props.path? then misc.path_split(@props.path).head

            <Row ref="preview" style={position:'absolute', bottom:'0px', width:'100%'}>
                <Col xs={0} sm={2}></Col>

                <Col xs={10} sm={9}>
                    <Well bsSize="small" style={@preview_style}>
                        <div className="pull-right lighten" style={marginRight: '-8px', marginTop: '-10px', cursor:'pointer', fontSize:'13pt'} onClick={@button_off_click}>
                            <Icon name='times'/>
                        </div>
                        {render_markdown(value, @props.project_id, file_path)}
                        <span className="pull-right small lighten">
                            Preview (press Shift+Enter to send)
                        </span>
                    </Well>
                </Col>

                <Col sm={1}></Col>
            </Row>

    render_timetravel_button: ->
        tip = <span>
            Browse all versions of this chatroom.
        </span>

        <Button onClick={@show_timetravel} bsStyle='info'>
            <Tip title='TimeTravel' tip={tip}  placement='left'>
                <Icon name='history'/> TimeTravel
            </Tip>
        </Button>

    render_bottom_button: ->
        tip = <span>
            Scrolls the chat to the bottom
        </span>

        <Button onClick={@button_scroll_to_bottom}>
            <Tip title='Scroll to Bottom' tip={tip}  placement='left'>
                <Icon name='arrow-down'/> Bottom
            </Tip>
        </Button>

    render_video_chat_button: ->
        <VideoChatButton
            project_id = {@props.project_id}
            path       = {@props.path}
            label      = {"Video Chat"}
        />

    render_search: ->
        <SearchInput
            placeholder   = {"Find messages..."}
            default_value = {@props.search}
            on_change     = {underscore.debounce(((value)=>@props.actions.setState(search:value)), 500)}
            style         = {margin:0}
        />

    render_button_row: ->
        # padding in first column is to match the message list itself.
        <Row style={marginTop:'5px'}>
            <Col xs={6} md={6} style={padding:'2px'}>
                {@render_search()}
            </Col>
            <Col xs={6} md={6} className="pull-right" style={padding:'2px', textAlign:'right'}>
                <ButtonGroup>
                    {@render_timetravel_button()}
                    {@render_video_chat_button()}
                    {@render_bottom_button()}
                </ButtonGroup>
            </Col>
        </Row>

    generate_temp_upload_text: (file) ->
        return "[Uploading...]\(#{file.name}\)"

    start_upload: (file, XMLRequest, FormData) ->
        text_area = ReactDOM.findDOMNode(@refs.input)
        temporary_insertion_text = @generate_temp_upload_text(file)
        temp_new_text = @props.input.slice(0, text_area.selectionStart) + temporary_insertion_text + @props.input.slice(text_area.selectionEnd)
        @props.actions.set_input(temp_new_text)

    append_file: (file) ->
        if file.type.indexOf("image") isnt -1
            final_insertion_text = "<img src=\".chat-images/#{file.name}\" width='100%'>"
        else
            final_insertion_text = "[#{file.name}](#{file.name})"

        temporary_insertion_text = @generate_temp_upload_text(file)
        start_index = @props.input.indexOf(temporary_insertion_text)
        end_index = start_index + temporary_insertion_text.length

        if start_index == -1
            return

        new_text = @props.input.slice(0, start_index) + final_insertion_text + @props.input.slice(end_index)
        @props.actions.set_input(new_text)

    render_body: ->
        chat_log_style =
            overflowY    : "auto"
            overflowX    : "hidden"
            margin       : "0"
            padding      : "0"
            paddingRight : "10px"
            background   : 'white'
            flex         : 1

        chat_input_style =
            margin       : "0"
            height       : '90px'
            fontSize     : @props.font_size

        <Grid fluid={true} className='smc-vfill' style={maxWidth: '1200px', display:'flex', flexDirection:'column'}>
            {@render_button_row() if not IS_MOBILE}
            <Row className='smc-vfill'>
                <Col className='smc-vfill' md={12} style={padding:'0px 2px 0px 2px'}>
                    <Well
                        style    = {chat_log_style}
                        ref      = 'log_container'
                        onScroll = {underscore.debounce(@save_scroll_position,SCROLL_DEBOUNCE_MS)}>
                        <ChatLog
                            messages     = {@props.messages}
                            account_id   = {@props.account_id}
                            user_map     = {@props.user_map}
                            project_id   = {@props.project_id}
                            font_size    = {@props.font_size}
                            file_path    = {if @props.path? then misc.path_split(@props.path).head}
                            actions      = {@props.actions}
                            saved_mesg   = {@props.saved_mesg}
                            search       = {@props.search}
                            set_scroll   = {@set_chat_log_state}
                            show_heads   = {true} />
                        {@render_preview_message() if @props.input.length > 0 and @props.is_preview}
                    </Well>
                </Col>
            </Row>
            <Row>
                <Col xs={10} md={11} style={padding:'0px 2px 0px 2px'}>
                    <SMC_Dropwrapper
                        project_id     = {@props.project_id}
                        dest_path      = {misc.normalized_path_join(@props.redux.getProjectStore(@props.project_id).get('current_path'), "/.chat-images")}
                        event_handlers = {complete : @append_file, sending : @start_upload}
                    >
                        <FormGroup>
                            <FormControl
                                autoFocus   = {not IS_MOBILE or isMobile.Android()}
                                rows        = {4}
                                componentClass = 'textarea'
                                ref         = 'input'
                                onKeyDown   = {@keydown}
                                value       = {@props.input}
                                placeholder = {'Type a message...'}
                                onChange    = {(e)=>@props.actions.set_input(e.target.value);  @mark_as_read()}
                                style       = {chat_input_style}
                            />
                        </FormGroup>
                    </SMC_Dropwrapper>
                </Col>
                <Col xs={2} md={1}
                    style={height:'90px', padding:'0', marginBottom: '0', display:'flex', flexDirection:'column'}
                    >
                    {<Button onClick={@button_on_click} disabled={@props.input==''}
                        bsStyle='info' style={height:'50%', width:'100%'}>
                        Preview
                    </Button> if not IS_MOBILE}
                    <Button onClick={@button_send_chat} disabled={@props.input==''}
                        bsStyle='success' style={flex:1, width:'100%'}>
                        Send
                    </Button>
                </Col>
            </Row>
            <Row>
                {@render_bottom_tip() if not IS_MOBILE}
            </Row>
        </Grid>


    render: ->
        if not @props.messages? or not @props.redux? or not @props.input?.length?
            return <Loading/>
        <div
            onMouseMove = {@mark_as_read}
            onClick     = {@mark_as_read}
            className   = "smc-vfill"
        >
            {@render_body()}
        </div>

