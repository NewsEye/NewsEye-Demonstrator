class @SVGUtils
    @text_collection: (type)->
        svg_parts = []
        color = switch status
            when "finished" then "#32CD32"
            when "running" then "#2E8B57"
            when "waiting" then "#C0C0C0"
            when "ready" then "#F4A460"
            else "#FF0000"
        svg_parts.push '<rect x="0" y="0" fill="#457B9D" height="80" rx="5" ry="5" width="200" stroke-width="10" stroke="'+color+'"/>'
        if type == "dataset"
            svg_parts.push '<text x="50%" y="50%" dominant-baseline="middle" fill="#EEEEEE" font-weight="bold" font-family="Verdana" font-size="30" text-anchor="middle">Dataset</text>'
        else if type == "search_query"
            svg_parts.push '<text x="50%" y="50%" dominant-baseline="middle" fill="#EEEEEE" font-weight="bold" font-family="Verdana" font-size="30" text-anchor="middle">Search</text>'
        return {svg: SVGUtils.generate_data(svg_parts, 200, 80), width: 200, height: 80}


    @split_by_facet: (status)->
        width = 80
        height = 80
        svg_parts = []
        color = switch status
            when "finished" then "#32CD32"
            when "running" then "#2E8B57"
            when "waiting" then "#C0C0C0"
            when "ready" then "#F4A460"
            else "#FF0000"
        svg_parts.push "<polygon x=\"0\" y=\"0\" width=\"#{width}\" height=\"#{height}\"
                                 points=\"#{width/2},0 #{width},#{height/2} #{width/2},#{height} 0,#{height/2}\"
                                 stroke=\"#{color}\" stroke-width=\"10\" fill=\"#F1FAEE\" />"
        svg_parts.push '<text x="50%" y="50%" dominant-baseline="middle" fill="#333333" font-weight="bold" font-family="Verdana" font-size="20" text-anchor="middle">Split</text>'
        return {svg: SVGUtils.generate_data(svg_parts, width, height), width: width, height: height}

    @analysis_tool: (status, tool_name)->
        width = 120
        height = 80
        svg_parts = []
        color = switch status
            when "finished" then "#32CD32"
            when "running" then "#2E8B57"
            when "waiting" then "#C0C0C0"
            when "ready" then "#F4A460"
            else "#FF0000"
        svg_parts.push '<rect x="0" y="0" fill="#F1FAEE" height="'+height+'" rx="5" ry="5" width="'+width+'" stroke-width="10" stroke="'+color+'"/>'
        tool_name = "<tspan text-anchor=\"middle\" dy=\"0\">#{tool_name}</tspan><tspan text-anchor=\"middle\" dy=\"20\">#{tool_name}</tspan>"
        svg_parts.push '<text x="50%" y="50%" dominant-baseline="middle" fill="#333333" font-weight="bold" font-family="Verdana" font-size="20" text-anchor="middle">'+tool_name+'</text>'
        return {svg: SVGUtils.generate_data(svg_parts, width, height), width: width, height: height}


    @generate_data: (svg_parts, width, height)->
        svgFile = '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE svg>'
        svgFile += "<svg xmlns='http://www.w3.org/2000/svg' version='1.1' width='#{width}' height='#{height}'>#{svg_parts}</svg>"
        data = 'data:image/svg+xml;utf8,' + encodeURIComponent(svgFile)
        return data

    @test: ()->
        width = 100
        height = 100
        color = "#000000"
        tool_name = "ExtractByFacet"
        ns = 'http://www.w3.org/2000/svg'
        svg = document.createElementNS(ns, 'svg')
        svg.setAttributeNS(null, 'width', width)
        svg.setAttributeNS(null, 'height', height)
        rect = document.createElementNS(ns, 'rect')
        rect_attr = {'x': 0, 'y': 0, 'width': width, 'height': height, 'rx': 5, 'ry': 5, 'fill': "#F1FAEE", 'stroke-width': 10, 'stroke': color}
        for attr of rect_attr
            rect.setAttributeNS(null, attr, rect_attr[attr])

        text_attr = {'dominant-baseline': 'middle', 'text-anchor': 'middle', 'font-family': 'Verdana', 'font-size': 20, 'font-weight': 'bold', 'fill': '#333333'}
        text = document.createElementNS(ns, 'text')
        text.setAttribute(attr, text_attr[attr]) for attr of text_attr
        tool_name_parts = tool_name.replace(/([a-z0-9])([A-Z])/g, '$1 $2').split(' ')
        for tool_name_part, index in tool_name_parts
            text.appendChild $("<tspan x=\"0\" y=\"#{index*20}\">#{tool_name_part}</tspan>")[0]

        bbox = text.getBBox()
        x = width/2
        y = (height/2) - bbox.y - bbox.height/2
        text.setAttribute('transform', "translate(#{x}, #{y})")
        return text.outerHTML
