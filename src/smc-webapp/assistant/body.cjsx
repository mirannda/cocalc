##############################################################################
#
#    CoCalc: Collaborative Calculation in the Cloud
#
#    Copyright (C) 2015 -- 2018, SageMath, Inc.
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

# global libs
_         = require('underscore')
immutable = require('immutable')
# react elements
{Col, Row, Panel, Button, FormGroup, Checkbox, FormControl, Well, Alert, Modal, Table, Nav, NavItem, ListGroup, ListGroupItem, InputGroup} = require('react-bootstrap')
{React, ReactDOM, redux, Redux, Actions, Store, rtypes, rclass} = require('../smc-react')
{Loading, Icon, Markdown, Space} = require('../r_misc')
# cocalc libs
{defaults, required, optional} = misc = require('smc-util/misc')


exports.ExamplesBody = rclass
    displayName : 'ExamplesBody'

    propTypes:
        actions             : rtypes.object
        data                : rtypes.immutable
        lang                : rtypes.string
        code                : rtypes.string
        descr               : rtypes.string
        setup_code          : rtypes.string
        prepend_setup_code  : rtypes.bool
        category0           : rtypes.number
        category1           : rtypes.number
        category2           : rtypes.number
        category_list0      : rtypes.arrayOf(rtypes.string)
        category_list1      : rtypes.arrayOf(rtypes.string)
        category_list2      : rtypes.arrayOf(rtypes.string)
        search_str          : rtypes.string
        search_sel          : rtypes.number
        hits                : rtypes.arrayOf(rtypes.array)
        unknown_lang        : rtypes.bool   # if true, show info about contributing to the assistant

    getDefaultProps: ->
        search_str : ''

    shouldComponentUpdate: (props, state) ->
        ret = misc.is_different(@props, props, [
            'data', 'lang', 'code', 'descr', 'setup_code', 'prepend_setup_code',
            'category0', 'category1', 'category2', 'search_str', 'search_sel', 'unknown_lang'
        ])
        ret or= misc.is_different_array(props.hits, @props.hits)
        ret or= misc.is_different_array(props.category_list0, @props.category_list0)
        ret or= misc.is_different_array(props.category_list1, @props.category_list1)
        ret or= misc.is_different_array(props.category_list2, @props.category_list2)
        return ret

    componentDidMount: ->
        @scrollTo0 = _.debounce((() -> $(ReactDOM.findDOMNode(@refs.list_0)).find('.active').scrollintoview()), 50)
        @scrollTo1 = _.debounce((() -> $(ReactDOM.findDOMNode(@refs.list_1)).find('.active').scrollintoview()), 50)
        @scrollTo2 = _.debounce((() -> $(ReactDOM.findDOMNode(@refs.list_2)).find('.active').scrollintoview()), 50)
        @scrollToS = _.debounce((() -> $(ReactDOM.findDOMNode(@refs.search_results_list)).find('.active').scrollintoview()), 50)

    componentDidUpdate: (props, state) ->
        @scrollTo0() if props.category0 != @props.category0
        @scrollTo1() if props.category1 != @props.category1
        @scrollTo2() if props.category2 != @props.category2
        @scrollToS() if props.search_sel != @props.search_sel

    category_selection: (level, idx) ->
        @props.actions.set_selected_category(level, idx)

    # level could be 0, 1 or 2
    render_category_list: (level) ->
        [category, list] = switch level
            when 0 then [@props.category0, @props.category_list0]
            when 1 then [@props.category1, @props.category_list1]
            when 2 then [@props.category2, @props.category_list2]
        list ?= []
        # don't use ListGroup & ListGroupItem with onClick, because then there are div/buttons (instead of ul/li) and layout is f'up
        <ul className={'list-group'} ref={"list_#{level}"}>
        {
            list.map (name, idx) =>
                click  = => @category_selection(level, idx)
                active = if idx == category then 'active' else ''
                <li
                    className  = {"list-group-item " + active}
                    onClick    = {click}
                    key        = {idx}
                >
                    <Markdown value={name} />
                </li>
        }
        </ul>

    search_result_selection: (idx) ->
        @props.actions.search_selected(idx)

    render_search_results: ->
        ss = @props.search_str
        <ul className={'list-group'} ref={'search_results_list'}>
        {
            @props.hits.map (hit, idx) =>
                [lvl1, lvl2, lvl3, title, descr, inDescr] = hit
                click = @search_result_selection.bind(@, idx)
                # highlight the match in the title
                title_hl = title.replace(new RegExp(ss, "gi"), "<span class='hl'>#{ss}</span>")
                # if the hit is in the description, highlight it too
                if inDescr != -1
                    i = Math.max(0, inDescr-30)
                    j = Math.min(descr.length, inDescr+30+ss.length)
                    t = descr[inDescr...inDescr+ss.length]
                    snippet = descr[i..j].replace(new RegExp(ss, "gi"), "<span class='hl'>#{t}</span>")
                    if i > 0
                        snippet = '...' + snippet
                    if j < descr.length
                        snippet = snippet + '...'
                active = if @props.search_sel == idx then 'active' else ''
                title_hl += ':' if snippet?.length > 0
                title = <span style={fontWeight: 'bold'} dangerouslySetInnerHTML={__html : title_hl}></span>
                snip = <span className={'snippet'} dangerouslySetInnerHTML={__html : snippet}></span> if snippet?.length > 0
                <li
                    key          = {idx}
                    className    = {"list-group-item " + active}
                    onClick      = {click}
                >
                    {lvl1} → {lvl2} → {title} {snip}
                </li>
        }
        </ul>

    render_top: ->
        searching = @props.search_str?.length > 0
        <Row key={'top'}>
        {
            if not @props.data?
                <Col md={12} className={'webapp-examples-loading'}>
                    <Loading style={fontSize:'150%'} />
                </Col>
            else if searching
                <Col sm={12}>
                    {@render_search_results()}
                </Col>
            else
                [
                    <Col sm={3} key={0}>{@render_category_list(0)}</Col>
                    <Col sm={3} key={1}>{@render_category_list(1)}</Col>
                    <Col sm={6} key={2}>{@render_category_list(2)}</Col>
                ]
        }
        </Row>

    render_bottom: ->
        # TODO syntax highlighting
        code = @props.code
        if @props.setup_code?.length > 0 and @props.prepend_setup_code
            code = "#{@props.setup_code}\n#{code}"
        <Row key={'bottom'}>
            <Col sm={6}>
                <pre ref={'code'} className={'code'}>{code}</pre>
            </Col>
            <Col sm={6}>
                <Panel ref={'descr'} className={'webapp-examples-descr'}>
                    <Markdown value={@props.descr} />
                </Panel>
            </Col>
        </Row>

    # top is the selector or search results list; bottom displays a selected document
    render_body: ->
        <React.Fragment>
            {@render_top()}
            {@render_bottom()}
        </React.Fragment>

    render_unknown_lang: ->
        {REPO_URL} = require('./main')

        <Row>
            <Col sm={12}>
                Selected language <code>{@props.lang}</code> has no data.
                You can help by contributing more content at{' '}
                <a href={REPO_URL} target={'_blank'}>
                    {REPO_URL.split('/')[-2...].join('/')}
                </a>.
            </Col>
        </Row>

    render: ->
        <Modal.Body className={'modal-body'}>
            {
                if @props.unknown_lang
                    @render_unknown_lang()
                else
                    @render_body()
            }
        </Modal.Body>