# FLOWTAG - parses and visualizes pcap data
# Copyright (C) 2007 Christopher Lee
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class ParallelCoordinatePlot
  STATE_NORMAL = 0
  STATE_FILTERED = 1
  STATE_SELECTED = 2
  STATE_CURRENT = 3
  STATES = [ 'normal', 'filtered', 'selected', 'current' ]
  
  @@default_colors = {
    'labels'   => 'grey75',
	  'axis'     => 'steelblue',
	  'labels'   => 'steelblue',
	  'selector' => 'red',
	  'state'    => [ 'grey70', 'grey40', '#999900', 'purple' ]
	}
  @@scales_in = {
    'lin' => proc { |x| x },
    'log' => proc { |x| (x<=0) ? 0 : Math.log(x) },
    'log2' => proc { |x| (x<=0) ? 0 : Math.log(x)/Math.log(2) },
    'log10' => proc { |x| Math.log10(x) },
    'sqrt' => proc { |x| Math.sqrt(x) },
    '3rt' => proc { |x| x ** (1/3.0) },
  }
  @@scales_out = {
    'lin' => proc { |x| x },
    'log' => proc { |x| Math.exp(x) },
    'log2' => proc { |x| 2 ** x },
    'log10' => proc { |x| 10 ** x },
    'sqrt' => proc { |x| x ** 2 },
    '3rt' => proc { |x| x ** 3 },
  }
  
  def pack(*args)
    @canvas.pack(*args)
  end
  
  def update
    @tuples.each do |k,t|
      @canvas.itemconfigure k, :fill => @colors['state'][t[0]]
    end
  end
  
  def set_tuple_state(key,state)
    @canvas.itemconfigure key, :fill => @colors['state'][state]
    @tuples[key][0] = state
    @canvas.raise key, 'all'
  end
  
  def addtuple(key,state,tuple)
    if tuple.length != @model.length
      puts "grr... what do I do now?  the tuple you gave me is a different length than the number of axes I have"
      return
    end
    axis = 0
    cx = cy = 0
    tuple.each do |item|
      x = axis2x(axis)
      y = item2y(axis, item)
      if cx > 0
        TkcLine.new(@canvas, cx, cy, x, y, :tags => [ key ], :fill => @colors['state'][state] )
      end
      cx = x
      cy = y
      axis += 1
    end
    @tuples[key] = [state,tuple]
  end
  
  def addtuples(tuples)
    tuples.each do |tuple|
      addtuple(tuple)
    end
  end
  
  def axis2x(axis)
    @model[axis][:x]
  end
  
  def item2y(axis, item)
    m = @model[axis]
    if m[:type] == 'range'
      scale = m[:scale]
      s_in = @@scales_in[scale]
      s_out = @@scales_out[scale]
      min = s_in.call m[:min]
      max = s_in.call m[:max]
      del = max - min
      y = @top_margin + (@draw_height * ((s_in.call(item) - min)/(del - min)))
      return y
    elsif m[:type] == 'list'
      c = 0
      m[:list].each do |i|
        break if item == i
        c += 1
      end
      y = @top_margin + (@draw_height * (c.to_f/m[:list].length))
      return y
    elsif m[:type] == 'date'
      raise "I must have fmt_in and fmt_out for a time axis.  Use the strftime codes for formatting.  E.g., %s => unix timestamp, %Y-%m-%d => SQL date (2007-12-12)" if m[:ifmt] == nil
      min = Date.strptime(m[:min],m[:ifmt])
      max = Date.strptime(m[:max],m[:ifmt])
      del = (max - min).to_i
      y = @top_margin + (@draw_height * ((Date.strptime(item,m[:ifmt]) - min)/(del - min)))
      return y
    end
  end
  
  def draw_axis
    axes = @model.length
    axes_spacing = @draw_width / (axes - 1.0)
    offset = @left_margin
    axis = 0
    @model.each do |m|
      m[:x] = offset
      #puts "#{offset} #{@top_margin} #{offset} #{@bottom_margin}"
      TkcLine.new(@canvas, offset, @top_margin, offset, @bottom_margin, :tags => ['axis'], :fill => @colors['axis'])
      offset += axes_spacing
      # lin, log, log10, sqrt, 3rt
      if m[:type] == 'range'
        scale = m[:scale]
        s_in = @@scales_in[scale]
        s_out = @@scales_out[scale]
        min = s_in.call m[:min]
        max = s_in.call m[:max]
        del = max - min
        if m[:items]
          m[:items].each do |itemx|
            item = s_in.call itemx
            y = @top_margin + (@draw_height * ((item - min)/(del - min)))
            text = itemx
            text = sprintf m[:ofmt], text if m[:ofmt]
            TkcText.new(@canvas, m[:x], y, :text => text, :anchor => (axis==0) ? 'e' : 'w', :fill => @colors['labels'], :tags => ['axislabel'])
          end
        else
          points = m[:points] || 20.0
          step = del / points.to_f
          item = min
          items = []
          ctext = nil
          (0..points).each do |i|
            y = @top_margin + (@draw_height * ((item - min)/(del - min)))
            text = s_out.call(item)
            text = sprintf m[:ofmt], text if m[:ofmt]
            unless text == ctext
              TkcText.new(@canvas, m[:x], y, :text => text, :anchor => (axis==0) ? 'e' : 'w', :fill => @colors['labels'], :tags => ['axislabel'])
            end
            ctext = text
            items.push item
            item += step
          end
          m[:items] = items
        end
      elsif m[:type] == 'list'
        # skip helps to mitigate overlap.  10.0 is what I assume the font size to be
        skip = (((m[:list].length * 10.0)/@draw_height) + 1).to_i
        item = 0
        items = []
        m[:list].each do |i|
          if item % skip == 0
            y = @top_margin + (@draw_height * (item.to_f/m[:list].length))
            i = sprintf m[:ofmt], i if m[:ofmt]
            TkcText.new(@canvas, m[:x], y, :text => i, :anchor => (axis==0) ? 'e' : 'w', :fill => @colors['labels'], :tags => ['axislabel'])
            items.push i
          end
          item += 1
        end
      elsif m[:type] == 'date'
        min = Date.strptime(m[:min],m[:ifmt])
        max = Date.strptime(m[:max],m[:ifmt])
        item = min
        del = (max - min).to_i
        points = m[:points] || 20.0
        step = del / points.to_f
        (0..points).each do |i|
          y = @top_margin + (@draw_height * (item - min)/(del - min))
          text = item.strftime m[:ofmt]
          TkcText.new(@canvas, m[:x], y, :text => text, :anchor => (axis==0) ? 'e' : 'w', :fill => @colors['labels'], :tags => ['axislabel'])
          item += step
        end
      end
      axis += 1
    end
  end
  
  def set_select_cb(callback)
    @select_cb = callback
  end

  def do_press(x, y)
    @start_x = x
    @start_y = y
    @current_rect = TkcRectangle.new(@canvas, x, y, x, y, :dash => '-', :outline => @colors['selector'])
  end
  
  def do_motion(x, y)
    if @current_rect
      @current_rect.coords @start_x, @start_y, x, y
      @canvas.itemconfigure 'selected', :fill => @colors['state'][STATE_NORMAL]
      @canvas.dtag 'selected'
      @canvas.addtag_overlapping 'selected', @start_x, @start_y, x, y
      @canvas.itemconfigure 'selected', :fill => @colors['state'][STATE_SELECTED]
      @current_rect.fill = ''
      @canvas.itemconfigure 'axis', :fill => @colors['axis']
      @canvas.itemconfigure 'axislabel', :fill => @colors['labels']
      # the below is slow, we need to find a faster way
      @tuples.each do |k,t|
        if t[0] == STATE_FILTERED
          @canvas.itemconfigure k, :fill => @colors['state'][STATE_FILTERED]
        end
      end
    end
  end
  
  def do_release(x, y)
    if @current_rect
      #@canvas.addtag_overlapping 'selected', @start_x, @start_y, x, y
      #@canvas.itemconfigure 'selected', :fill => @colors['state'][STATE_SELECTED]
      @current_rect.delete
      @current_rect = nil
      tuples = []
      # stopped here BOOKMARK
      items = @canvas.find_withtag 'selected'
      items.each do |item|
        item.gettags.each do |tag|
          if tag =~ /\|/ and @tuples[tag][0] != STATE_FILTERED
            tuples.push( tag.split(/\|/) )
          end
        end
      end
      @select_cb.call(tuples) if @select_cb and tuples.length > 0
    end
  end
  
  def setPalette(*args)
    return unless args.length > 0
    args[0].each do |k,v|
      @colors[k] = v
    end
  end
  
  def initialize(parent, h, w, model)
    @model = model
    @canvas = TkCanvas.new(parent) {
      height h
      width w
    }
    @canvas.pack 
    @left_margin = 50
    @right_margin = w - 90
    @top_margin = 10
    @bottom_margin = h - 10
    @draw_width = @right_margin - @left_margin
    @draw_height = @bottom_margin - @top_margin
    @canvas.bind("1", proc{|e| do_press(e.x, e.y)})
    @canvas.bind("B1-Motion", proc{|x, y| do_motion(x, y)}, "%x %y")
    @canvas.bind("ButtonRelease-1", proc{|x, y| do_release(x, y)}, "%x %y")
    @colors = @@default_colors
    @tuples = {}
    draw_axis
  end
end
