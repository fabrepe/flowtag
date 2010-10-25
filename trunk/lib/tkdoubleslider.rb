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

class TkDoubleSlider
  def pack(*args)
    @canvas.pack(*args)
  end

  def redraw
  	@canvas.delete('all');
  	x1 = value2x(@low)
  	x2 = value2x(@high)
  	y = @height/2
  	TkcText.new(@canvas, 2, @height - 2, :text=>@label, :anchor=>'sw', :fill => @colors[:text]) if @label
  	TkcLine.new(@canvas, @left_margin, y, @width - @right_margin, y, :fill => @colors[:line], :width => 1, :tags => ['track'])
  	TkcLine.new(@canvas, @left_margin, y, @width - @right_margin, y, :fill => @colors[:line], :width => 4, :tags => ['selection'])
  	TkcOval.new(@canvas, x1 - @ballsize, y - @ballsize, x1 + @ballsize, y + @ballsize, :fill => @colors[:low_head], :width => 1, :tags => ['low'])
  	TkcOval.new(@canvas, x2 - @ballsize, y - @ballsize, x2 + @ballsize, y + @ballsize, :fill => @colors[:high_head], :width => 1, :tags => ['high'])
  	if @valuefmt
  	  TkcText.new(@canvas, x1, @top_margin, :text => @valuefmt.call(@low), :tags => ['lowvalue'], :fill => @colors[:text])
  	  TkcText.new(@canvas, x2, @height - @bottom_margin, :text => @valuefmt.call(@high), :tags => ['highvalue'], :fill => @colors[:text])
  	  fmt = @deltafmt || @valuefmt  # use delta format instead of value format if it is defined
  	  TkcText.new(@canvas, (x1+x2)/2, y, :text => fmt.call(@high - @low), :tags => ['delta'], :fill => @colors[:delta])
  	  coords = @canvas.bbox('delta')
   	  TkcRectangle.new(@canvas,coords[0], coords[1], coords[2], coords[3], :fill => @colors[:background], :tags => ['deltabg'], :outline => @colors[:background]) if coords.length > 0
  	  @canvas.raise('delta','all')
	  end
	  @canvas.itembind('low', 'ButtonPress-1', proc { @sel = 'low' })
	  @canvas.itembind('high', 'ButtonPress-1', proc { @sel = 'high' })
	  @canvas.itembind('all', 'ButtonRelease-1', proc { @sel = nil })
	  @canvas.itembind('low||high', 'Button1-Motion', proc { |x,y| move(@sel,x,y) }, "%x %y")  
  end
  
  def move(tag, x, y)
    return unless @sel
    @canvas.raise @sel, 'all'
    x = @left_margin if x < @left_margin
    x = @width - @right_margin if x > @width - @right_margin
    x = value2x(snap(x2value(x)))
  	y = @height/2
    # don't update the text and deltas unless they need to be updated
    return if instance_variable_get("@#{@sel}") == x2value(x)
    instance_variable_set("@#{@sel}",x2value(x))
    @canvas.coords(@sel, x - @ballsize, y - @ballsize, x + @ballsize, y + @ballsize)
    if @sel == 'low' and @low > @high
      @high = @low
      @canvas.coords('high', x - @ballsize, y - @ballsize, x + @ballsize, y + @ballsize)
    elsif @sel == 'high' and @high < @low
      @low = @high
      @canvas.coords('low', x - @ballsize, y - @ballsize, x + @ballsize, y + @ballsize)
    end
    lx = value2x(@low)
    hx = value2x(@high)
    @canvas.coords('selection', lx, y, hx, y)
    if @valuefmt
      @canvas.coords('lowvalue', lx, @top_margin)
      @canvas.coords('highvalue', hx, @height - @bottom_margin)
      @canvas.coords('delta', (lx+hx)/2, y)
      @canvas.itemconfigure('lowvalue', :text => @valuefmt.call(@low))
      @canvas.itemconfigure('highvalue', :text => @valuefmt.call(@high))
  	  fmt = @deltafmt || @valuefmt  # use delta format instead of value format if it is defined
      @canvas.itemconfigure('delta', :text => fmt.call(@high - @low))
      coords = @canvas.bbox('delta')
      w1 = coords[2] - coords[0]
      if coords[0] < lx +5
        if lx < @width/2
          coords2 = @canvas.bbox('lowvalue')
          ox = coords2[2] + 10 + (w1/2)
          oy = @top_margin
          @canvas.coords('delta',ox,oy)
        else
          coords2 = @canvas.bbox('highvalue')
          ox = coords2[0] - 10 - (w1/2)
          oy = @height - @bottom_margin
          @canvas.coords('delta',ox,oy)
        end
      end
      coords = @canvas.bbox('delta')
      @canvas.coords('deltabg', coords[0], coords[1], coords[2], coords[3])
    end
    @change_cb.call(@low,@high) if @change_cb
  end

  def snap(x)
    return x unless @snap
    return @max if x > @max - @snap
    x = (x - (x % @snap)).to_i
    return x
  end

  def x2value(x)
    x = @left_margin if x < @left_margin
    r = @width - @right_margin
    x = r if x > r
    l = @left_margin
    o = (x - l).to_f
    dx = (r - l).to_f
    frac = o/dx
    if @logbase
      return @max**(o/dx)
    else
      return @min+((o/dx)*(@max - @min))
    end
  end
  
  def value2x(v)
    v = @max if v > @max
    v = @min if v < @min
    w = @width - @left_margin - @right_margin
    if @logbase
      return @left_margin + (Math.log(v)*w/Math.log(@max))
    else
      return @left_margin + (((v - @min).to_f/(@max - @min).to_f)*w)
    end
  end

  attr_accessor :change_cb, :valuefmt, :colors
  def initialize(parent,*args)
    @height = 36.0
    @width = 360.0
    @min = @max = @low = @high = 0.0
    @ballsize = 5
    @snap = false
    @logbase = false
    @colors = {
      :background => 'grey20',
      :line => 'grey75',
      :low_head => '#996666',
      :high_head => '#996666',
      :text => 'white',
      :delta => 'white',
    }
    @left_margin = 10.0
    @right_margin = 20.0
    @top_margin = 6.0
    @bottom_margin = 4.0
    @selection = nil
    @change_cb = nil
    @valuefmt = proc { |x| sprintf "%d", x }
    @deltafmt = nil
    @label = nil
    if args.length > 0
      args[0].each do |k,v|
        if instance_variable_defined?("@#{k}")
          if v =~ /^[\d\.]+$/
            instance_variable_set("@#{k}", v.to_f)
          else
            instance_variable_set("@#{k}", v)
          end
        end
      end
    end
    @canvas = TkCanvas.new(parent, :width => @width, :height => @height, :scrollregion => [0, 0, @width, @height])
    @canvas.configure('background', @colors[:background]) if @colors[:background]
    redraw
  end
end