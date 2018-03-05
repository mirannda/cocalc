##############################################################################
#
#    CoCalc: Collaborative Calculation in the Cloud
#
#    Copyright (C) 2018, Sagemath Inc.
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

path      = require('path')
path_join = path.join
immutable = require('immutable')
_         = require('underscore')

# CoCalc libraries
{defaults, required} = misc = require('smc-util/misc')
{COLORS}             = require('smc-util/theme')
{Avatar}             = require('../../other-users')

# React libraries
{React, rclass, rtypes} = require('../../smc-react')
{DateTimePicker, ErrorDisplay, Icon, LabeledRow, Loading, MarkdownInput, Space, Tip, NumberInput} = require('../../r_misc')
{Alert, Button, ButtonToolbar, ButtonGroup, Form, FormControl, FormGroup, ControlLabel, InputGroup, Checkbox, Row, Col, Panel, Breadcrumb} = require('react-bootstrap')

# grading specific
{BigTime} = require('../common')
{Grading} = require('./models')
{ROW_STYLE, LIST_STYLE, LIST_ENTRY_STYLE, FLEX_LIST_CONTAINER, EMPTY_LISTING_TEXT, PAGE_SIZE} = require('./const')

exports.StudentList = rclass
    displayName : 'CourseEditor-GradingStudentAssignment-StudentList'

    propTypes:
        name            : rtypes.string.isRequired
        store           : rtypes.object.isRequired
        grading         : rtypes.instanceOf(Grading).isRequired
        assignment      : rtypes.immutable.Map
        student_list    : rtypes.arrayOf(rtypes.object)
        student_filter  : rtypes.string
        student_id      : rtypes.string
        account_id      : rtypes.string

    student_list_entry_click: (student_id) ->
        @actions(@props.name).grading(
            assignment       : @props.assignment
            student_id       : student_id
            direction        : 0
            without_grade    : null
        )

    set_student_filter: (string) ->
        @setState(student_filter:string)
        @actions(@props.name).grading_set_student_filter(string)

    on_key_down_student_filter: (e) ->
        switch e.keyCode
            when 27
                @set_student_filter('')
            when 13
                @pick_next()
                e?.preventDefault?()

    student_list_filter: ->
        disabled = @props.student_filter?.length == 0 ? true

        <form key={'filter_list'} style={{}}>
            <FormGroup>
                <InputGroup>
                    <InputGroup.Addon>
                        Search
                    </InputGroup.Addon>
                    <FormControl
                        autoFocus   = {true}
                        ref         = {'stundent_filter'}
                        type        = {'text'}
                        placeholder = {'any text...'}
                        value       = {@props.student_filter}
                        onChange    = {(e)=>@set_student_filter(e.target.value)}
                        onKeyDown   = {@on_key_down_student_filter}
                    />
                    <InputGroup.Button>
                        <Button
                            bsStyle  = {if disabled then 'default' else 'warning'}
                            onClick  = {=>@set_student_filter('')}
                            disabled = {disabled}
                            style    = {whiteSpace:'nowrap'}
                        >
                            <Icon name='times-circle'/>
                        </Button>
                    </InputGroup.Button>
                </InputGroup>
            </FormGroup>
        </form>


    render_student_list_entries_info: (active, grade_val, points, is_collected) ->
        col = if active then COLORS.GRAY_LL else COLORS.GRAY
        info_style =
            color          : col
            display        : 'inline-block'
            float          : 'right'

        show_grade  = grade_val?.length > 0
        show_points = points? or is_collected
        grade  = if show_grade  then misc.trunc(grade_val, 15) else 'N/G'
        points = if show_points then ", #{points ? 0} pts."    else ''

        if show_points or show_grade
            <span style={info_style}>
                {grade}{points}
            </span>
        else
            null

    render_student_list_presenece: (student_id) ->
        # presence of other teachers
        # cursors are only relevant for the last 10 minutes (componentDidMount updates with a timer)
        min_10_ago = misc.server_minutes_ago(10)
        presence = []
        whoelse = @props.grading.getIn(['cursors', @props.assignment.get('assignment_id'), student_id])
        whoelse?.map (time, account_id) =>
            return if account_id == @props.account_id or time < min_10_ago
            presence.push(
                <Avatar
                    key        = {account_id}
                    size       = {22}
                    account_id = {account_id}
                />
            )
            return

        style =
            marginLeft    : '10px'
            display        : 'inline-block'
            marginTop      : '-5px'
            marginBottom   : '-5px'

        if presence.length > 0
            <div style={style}>
                {presence}
            </div>


    render_student_list_entries: ->
        style        = misc.merge({cursor:'pointer'}, LIST_ENTRY_STYLE)
        avatar_style =
            display        : 'inline-block'
            marginRight    : '10px'
            marginTop      : '-5px'
            marginBottom   : '-5px'

        list = @props.student_list.map (student) =>
            student_id   = student.get('student_id')
            account_id   = student.get('account_id')
            name         = @props.store.get_student_name(student)
            points       = @props.store.get_points_total(@props.assignment, student_id)
            is_collected = @props.store.student_assignment_info(student_id, @props.assignment)?.last_collect?.time?

            # should this student be highlighted in the list?
            current      = @props.student_id == student_id
            active       = if current then 'active' else ''
            grade_val    = @props.store.get_grade(@props.assignment, student_id)

            <li
                key        = {student_id}
                className  = {"list-group-item " + active}
                onClick    = {=>@student_list_entry_click(student_id)}
                style      = {style}
            >
                <span style={float:'left'}>
                    {<div style={avatar_style}>
                        <Avatar
                            size       = {22}
                            account_id = {account_id}
                        />
                    </div> if account_id?}
                    {name}
                    {@render_student_list_presenece(student_id)}
                </span>
                {@render_student_list_entries_info(active, grade_val, points, is_collected)}
            </li>

        if list.length == 0
            list.push(<div style={EMPTY_LISTING_TEXT}>No student matches…</div>)
        return list

    render: ->
        flex =
            display        : 'flex'
            flexDirection  : 'column'

        [
            <Row key={1}>
                {@student_list_filter()}
            </Row>
            <Row style={FLEX_LIST_CONTAINER} key={2}>
                <ul className='list-group' ref='student_list' style={LIST_STYLE}>
                    {@render_student_list_entries()}
                </ul>
            </Row>
        ]
