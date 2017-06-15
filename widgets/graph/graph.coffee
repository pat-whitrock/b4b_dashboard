class Dashing.Graph extends Dashing.Widget

  @accessor 'current', ->
    return @get('displayedValue') if @get('displayedValue')
    points = @get('points')
    if points
      points[points.length - 1].y

  ready: ->
    container = $(@node).parent()
    # Gross hacks. Let's fix this.
    width = (Dashing.widget_base_dimensions[0] * container.data("sizex")) + Dashing.widget_margins[0] * 2 * (container.data("sizex") - 1)
    height = (Dashing.widget_base_dimensions[1] * container.data("sizey"))
    @graph = new Rickshaw.Graph(
      element: @node
      width: width
      height: height
      renderer: @get("graphtype")
      series: [
        {
        color: "#fff",
        data: [{x:0, y:0}]
        }
      ]
      padding: {top: 0.02, left: 0.02, right: 0.02, bottom: 0.02}
    )

    @graph.series[0].data = @get('points') if @get('points')

    month = (n) -> switch n %% 12
      when 1 then "Jan"
      when 2 then "Feb"
      when 3 then "Mar"
      when 4 then "Apr"
      when 5 then "May"
      when 6 then "Jun"
      when 7 then "Jul"
      when 8 then "Aug"
      when 9 then "Sep"
      when 10 then "Oct"
      when 11 then "Nov"
      when 0 then "Dec"
      else "Ignore"
    year = (n) -> "#{n // 12 %% 100}"
    format = (n) -> if month(n) == "Ignore" then "" else "#{month(n)} #{year(n)}"

    x_axis = new Rickshaw.Graph.Axis.X(graph: @graph, tickFormat: format)
    y_axis = new Rickshaw.Graph.Axis.Y(graph: @graph, tickFormat: Rickshaw.Fixtures.Number.formatKMBT)
    @graph.render()

  onData: (data) ->
    if @graph
      @graph.series[0].data = data.points
      @graph.render()
