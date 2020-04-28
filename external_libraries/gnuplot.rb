#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = gnuplot utility
## Author:: Anonymous3
## Version:: 1.0 2004/12/01
## === History
## * [2004/12/01]: Create This File.
## * [2014/08/17]: reform the file
## * [2014/08/17]: introduce error bar facility
## * [2015/06/06]: change "ls" (linestyle) to "lt" (linetype).
##                 "ls" becomes obsolute in recent gnuplot.
#------------------------------------------------------------
#++
## == Usage
## === sample 1
#
#	gplot = Gnuplot::new("x11") ; # or "tgif"
#	gplot.setTitle("This is a test.") ;
#	gplot.setXYLabel("X axis","Y axis") ;
#	gplot.command('plot [0:10] x*x') ;
#	gplot.close() ;
#
#------------------------------------------------------------
#++
## === sample 2
#
#	Gnuplot::directPlot() {|gplot|
#	  (0...10).each{|x|
#	    gplot.dpXYPlot(x,x*x) ;
#	    gplot.dpFlush() if dynamicP
#	  }
#	}
#
#------------------------------------------------------------
#++
## === sample 3
#
#	gplot = Gnuplot::new() ;
#	gplot.dpBegin() ;
#	(0...10).each{|x|
#	  gplot.dpXYPlot(x,x*x) ;
#	  gplot.dpFlush() if dynamicP
#	}
#	gplot.dpEnd() ;
#	gplot.close() ;
#
#------------------------------------------------------------
#++
## === sample 4
#
#	Gnuplot::directMultiPlot(3) {|gplot|
#	  gplot.dmpSetTitle(0,"foo") ;
#	  gplot.dmpSetTitle(1,"bar") ;
#	  gplot.dmpSetTitle(2,"baz") ;
#	  (0...10).each{|x|
#	    gplot.dmpXYPlot(0,x,x*x) ;
#	    gplot.dmpXYPlot(1,x,sin(x)) ;
#	    gplot.dmpXYPlot(2,x,cos(x)) ;
#	    gplot.dmpFlush() if dynamicP 
#	  }
#	}

require 'tempfile' ;

#--======================================================================
#++
## class to access GnuPlot
class Gnuplot

  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## adaptation of colors for visibility
  Colors = "-xrm 'gnuplot*line2Color:darkgreen'"

  ## workfile basename (used for dynamic plotting)
  DfltWorkfileBase = "RubyGnuplot" ;

  ## default styles
  DfltPlotStyle = "w linespoints" ; 
  DfltPlotStyleForFunc = "w lines" ;
  
  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  ## command
  #@@command = "gnuplot #{Colors} -persist %s >& /dev/null" ;
  #@@command = "gnuplot #{Colors} -persist %s |& cat" ;
  @@command = "gnuplot #{Colors} -persist %s" ;

  ## default terminal setting
  @@defaultTerm = "x11" ;
#  @@defaultTerm = "tgif" ;

  ## default filename base for output
  @@defaultFileNameBase = "foo" ;

  #--------------------------------------------------------------
  #++
  ## change the filename base
  def Gnuplot.setTermFileBase(term, filebase = @@defaultFileNameBase)
    @@defaultTerm = term ;
    @@defaultFileNameBase = filebase ;
  end

  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  attr :strm, true ;
  attr :m, true ;
  attr :workstrm, true ;
  attr :workfile, true ;
  attr :errbarstrm, true ; ## for error bar
  attr :errbarfile, true ; ## for error bar
  attr :datafile, true ;
  attr :title,    true ;
  attr :hline,    true ;
  attr :scriptfile, true ;
  attr :timeMode, true ;
  attr :sustainedMode, true ;
  attr :preValue, true ;

  #--------------------------------------------------------------
  #++
  ## init
  def initialize(term = nil,
                 filenamebase = nil, 
                 comlineOpt = nil)
    term = @@defaultTerm if term.nil? ;
    filenamebase = @@defaultFileNameBase if filenamebase.nil? ;
    myopen(term, filenamebase, comlineOpt) ;
    if(!saveScript?())
      setTerm(term, filenamebase) ;
    end
    @hline = [] ;
    @timeMode = false ;
    @sustainedMode = false ;
    @preValue = {} ;
  end

  #--------------------------------------------------------------
  #++
  ## invoke gnuplot command
  def myopen(term, filenamebase, comlineOpt) 
    if(term == "gplot" || term == :gplot)
      @scriptfile = filenamebase + ".gpl" ;
      @strm = open(@scriptfile, "w") ;
    else
      opt = comlineOpt ;
      opt = "" if opt.nil? ;
#        @strm = open("|" + (@@command % opt) ,"w") ;
        @strm = IO.popen((@@command % opt) ,"r+") ;
        @thread = Thread.new(@strm){ |s|
          begin
            while(l = s.gets) 
              puts l ;
            end
          rescue => ex
            if(ex.is_a?(IOError) && ex.message == "closed stream") then
            else
              raise ex.exception ;
            end
          end
        }
        
      #@strm = STDOUT ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## check save script or not
  def saveScript?()
    return !@scriptfile.nil? ;
  end

  #--------------------------------------------------------------
  #++
  ## close the command stream
  def close()
    @strm.print("quit\n") ;
    @strm.close() ;
    sleep(0.1) ;  ## for the safety to terminate stream.
  end

  #--------------------------------------------------------------
  #++
  ## set terminal setting of gnuplot
  def setTerm(term,filenamebase = "foo") 
    termopt = "" ;
    setout = true ;
    case(term)
    when "tgif", :tgif
      suffix="obj" ;
      termopt = "solid" ;
    when "postscript", :postscript, :ps
      suffix="ps" ;
    when "gplot", :gplot
      suffix="gp" ;
    else
      setout = false ;
    end

    @strm.printf("set term %s %s\n",term,termopt) ;
    
    
    if(setout) then
      @strm.printf("set out \"%s.%s\"\n",filenamebase,suffix) ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## set graph title
  def setTitle(title) 
    @strm.printf("set title \"%s\"\n",title) ;
  end

  #--------------------------------------------------------------
  #++
  ## set time format
  def setTimeFormat(xy,inFormat, outFormat = nil)
    case(xy)
    when :x
      command("set xdata time") ;
      command("set format x \"#{outFormat}\"") if (outFormat) ;
    when :y
      command("set ydata time") ;
      command("set format y \"#{outFormat}\"") if (outFormat) ;
    when :xy
      command("set xdata time") ;
      command("set ydata time") ;
      command("set format x \"#{outFormat}\"") if (outFormat) ;
      command("set format y \"#{outFormat}\"") if (outFormat) ;
    else
      raise "unknown xy-flag for setTimeFormat:" + xy.to_s ;
    end
    @timeMode = true ;
    command("set timefmt \"#{inFormat}\"") ;
  end

  #--------------------------------------------------------------
  #++
  ## set labels for X and Y axes
  def setXYLabel(xlabel,ylabel)
    @strm.printf("set xlabel \"%s\"\n",xlabel) ;
    @strm.printf("set ylabel \"%s\"\n",ylabel) ;
  end

  #--------------------------------------------------------------
  #++
  ## sustainable mode
  def setSustainedMode(mode = true)
    @sustainedMode = mode ;
  end

  #--------------------------------------------------------------
  #++
  ## key (plot description) positioning
  def setKeyConf(configstr) # see gnuplot set key manual
                         # useful keyword: left, right, top, bottom
                         #                 outside, below
    @strm.printf("set key %s\n",configstr) ;
  end

  #--------------------------------------------------------------
  #++
  ## general facility to set gnuplot parameter
  def setParam(param, value) ;
    @strm.printf("set %s %s\n", param, value) ;
  end

  #--------------------------------------------------------------
  #++
  ## plot horizontal line in the graph
  def pushHLine(label,value,style = nil)
    @hline.push([label, value, style]) ;
  end

  #--------------------------------------------------------------
  #++
  ## send command to gnuplot
  def command(comstr)
    if(comstr.is_a?(Array)) 
      comstr.each{ |com| command(com) ; } ;
    end
    
    @strm.print(comstr) ;
    @strm.print("\n") ;
  end

  #--------------------------------------------------------------
  #++
  ## ==== direct ploting

  #------------------------------------------
  #++
  ## direct plot begin
  def dpBegin() 
    @workstrm = Tempfile::new(DfltWorkfileBase) ;
    @workfile = @workstrm.path ;
    @datafile = nil ;
  end

  #------------------------------------------
  #++
  ## set datafile to save
  def dpSetDatafile(datafilename)
    @datafile = datafilename ;
  end

  #------------------------------------------
  #++
  ## direct plot 
  ## _x_:: x value.
  ## _y_:: y value. 
  ##       If _y_ is an Array, it is treated as [ave, error] or
  ##       [ave, min, max]
  def dpXYPlot(x,y) ;
    if(y.is_a?(Array)) ## the case with error bar values
      dpXYPlot(x,y[0]) ;
      if(y.size > 1) then
        prepareErrorBarStream() ;
        @errbarstrm << x ;
        y.each{|value|
          @errbarstrm << " " << value ;
        }
        @errbarstrm << "\n" ;
      end
    else ## no error bar case
      if(@sustainedMode && @preValue[:main])
        @workstrm << x << " " << @preValue[:main] << "\n" ;
      end
      @workstrm << x << " " << y << "\n" ;

      @preValue[:main] = y ;
    end
  end

  #------------------------------------------
  #++
  ## direct plot flush and show
  def dpFlush(rangeopt = "", styles = DfltPlotStyle) 
    @workstrm.flush ;
    @errbarstrm.flush if(@errbarstrm) ;
    dpShow(rangeopt, styles) ;
  end

  #------------------------------------------
  #++
  ## direct plot end
  def dpEnd(showp = true, rangeopt = "", styles = DfltPlotStyle) 
    @workstrm.close() ;
    @errbarstrm.close() if(@errbarstrm) ;

    # copy data file for save
    if(!@datafile.nil?) then
      system(sprintf("cp %s %s",@workfile,@datafile)) ;
    end

    # show result
    if(showp) then
      dpShow(rangeopt,styles) ;
    end
  end

  #------------------------------------------
  #++
  ## direct plot show result
  def dpShow(rangeopt = "", styles = DfltPlotStyle) 
    styleCount = 1 ;
    styles = "using 1:2 " + styles if(@timeMode) ;
#    styles += " ls #{styleCount}" ;
    styles += " lt #{styleCount}" ;
    datafile = @workfile ;
    if(saveScript?())
      datafile = '-' ;
    end
    com = sprintf("plot %s \"%s\" %s",rangeopt,datafile,styles) ;

    ## error bar
    if(@errbarstrm)
#      com += (", \"%s\" w yerrorbars ls %d notitle" % 
      com += (", \"%s\" w yerrorbars lt %d notitle" % 
              [@errbarfile,styleCount]) ;
    end

    ## horizontal lines
    @hline.each{|line|
      label = line[0] ;
      value = line[1] ;
      style = (line[2].nil?) ? "dots" : line[2] ;

      com += (", %s title '%s' with %s" % [value.to_s, label, style]) ; 
      
    }

    command(com) ;

    if(saveScript?())
      open(@workfile){|strm|
        strm.each{|line|
          @strm << line
        }
      }
      @strm << "e\n" ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## direct multiple ploting

  #------------------------------------------
  #++
  ## prepare error bar streams
  ## _key_:: if nil, it is for direct plot.  
  ##         if nonnil, it is for direct multi plot.
  ## *return*:: a stream if the preparation executed. 
  ##            nil if the preparation was done.
  def prepareErrorBarStream(key = nil)
    if(key.nil?)  #  for direct plot
      if(@errbarstrm.nil?) then
        @errbarstrm = Tempfile::new(DfltWorkfileBase) ;
        @errbarfile = @errbarstrm.path ;
        return @errbarstrm ;
      elsif(@errbarstrm.is_a?(Tempfile))
        return nil ;
      else
        raise("@errbarstrm was parepared for direct multi plot, " +
              "but also is prepared for direct plot again.") ;
      end
    else # for direct multi plot
      if(@errbarstrm.nil?) then
        raise("@errbarstrm is parepared for direct multi plot " +
               "without direct multi plot setup.") ;
      elsif(@errbarstrm[key].nil?)
        @errbarstrm[key] = Tempfile::new(DfltWorkfileBase) ;
        @errbarfile[key] = @errbarstrm[key].path ;
        return @errbarstrm[key] ;
      else
        return nil ;
      end
    end
  end

  #------------------------------------------
  #++
  ## direct multiple plot begin
  def dmpBegin(m)
    if(m.is_a?(Integer))
      @m = m ;
      @workstrm = Array::new(m) ;
      @workfile = Array::new(m) ;
      @errbarstrm = Array::new(m) ;
      @errbarkfile = Array::new(m) ;
      @datafile = Array::new(m) ;
      @title = Array::new(m) ;
      @layerList = (0...m) ;
      @workcount = Hash.new ;
      @plotFunc = Hash.new ;
    elsif(m.is_a?(Array))
      @m = m.size ;
      @workstrm = Hash.new ;
      @workfile = Hash.new ;
      @errbarstrm = Hash.new ;
      @errbarfile = Hash.new ;
      @datafile = Hash.new ;
      @title = Hash.new ;
      @layerList = m ;
      @workcount = Hash.new ;
      @plotFunc = Hash.new ;
    else
      raise "unknown index for multiple plot: #{m}" ;
    end

    @localStyle = {} ;

    @layerList.each{|i| 
      @workstrm[i] = Tempfile::new(DfltWorkfileBase) ;
      @workstrm[i] << '#' << "\n" ;
      @workfile[i] = @workstrm[i].path ;
      @datafile[i] = nil ;

#      if(i.is_a?(Array)) then
#        @title[i] = i.join(',') ;
#      else
#        @title[i] = i.to_s ;
#      end
      if(i.is_a?(String)) then
        @title[i] = i ;
      else
        @title[i] = i.inspect ;
      end

      @workcount[i] = 0 ;
    }
  end

  #------------------------------------------
  #++
  ## set datafile to save
  def dmpSetDatafile(k,datafilename)
    @datafile[k] = datafilename ;
  end

  #------------------------------------------
  #++
  ## set title for each plot
  def dmpSetTitle(k,title)
    @title[k] = title ;
  end

  #------------------------------------------
  #++
  ## set style for each plot
  def dmpSetStyle(k,style)
    @localStyle[k] = style ;
  end

  #------------------------------------------
  #++
  ## set style for each plot
  def dmpPlotFunc(k, funcForm, style = DfltPlotStyleForFunc)
    @plotFunc[k] = funcForm ;
    @workcount[k] += 1 ;
    dmpSetStyle(k,style) ;
  end

  #------------------------------------------
  #++
  ## direct multiple plot end
  ## _k_:: key of the plot.
  ## _x_:: x value.
  ## _y_:: y value. 
  ##       If _y_ is an Array, it is treated as [ave, error] or
  ##       [ave, min, max]
  def dmpXYPlot(k,x,y)
    if(y.is_a?(Array)) ## the case with error bar values
      dmpXYPlot(k,x,y[0]) ;
      if(y.size > 1) then
        prepareErrorBarStream(k) ;
        @errbarstrm[k] << x ;
        y.each{|value|
          @errbarstrm[k] << " " << value ;
        }
        @errbarstrm[k] << "\n" ;
      end
    else ## no error bar case
      if(@sustainedMode && @preValue[k])
        @workstrm[k] << x << " " << @preValue[k] << "\n" ;
      end
      @workcount[k] += 1;
      @workstrm[k] << x << " " << y << "\n" ;

      @preValue[k] = y ;
    end
  end

  #------------------------------------------
  #++
  ## direct multiple plot end
  def dmpFlush(rangeopt = "", styles = DfltPlotStyle)
    @layerList.each{|k|
      @workstrm[k].flush() ;
      @errbarstrm[k].flush() if(@errbarstrm[k]);
    }
    dmpShow(rangeopt, styles) ;
  end

  #------------------------------------------
  #++
  ## direct multiple plot end
  def dmpEnd(showp = true, rangeopt = "", styles = DfltPlotStyle)
    @layerList.each{ |i|
      @workstrm[i].close() ;
      @errbarstrm[i].close() if(@errbarstrm[i]) ;

      # copy data file for save
      if(!@datafile[i].nil?) then
	system(sprintf("cp %s %s",@workfile[i],@datafile[i])) ;
      end
    }

    # show result
    if(showp) then
      dmpShow(rangeopt,styles) ;
    end
  end

  #------------------------------------------
  #++
  ## direct multi plot show result
  def dmpShow(rangeopt = "", styles = DfltPlotStyle)
    com = sprintf("plot %s",rangeopt) ;
    firstp = true ;

    inlineDataList = [] ;

    styleCount = 0 ;
    @layerList.each{|k|
      next if (@workcount[k] <= 0) ;
      if(firstp) then
	com += " " ;
	firstp = false ;
      else
	com += ", " ;
      end

      styleCount += 1 ;
      if(saveScript?())
        inlineDataList.push(@workfile[k]) ;
        file = '-' ;
      else
        file = @workfile[k] ;
      end

      localstyle = @localStyle[k] || styles ;
      using = (@timeMode ? "using 1:2" : "") ;

      plotObject = (@plotFunc[k] ? @plotFunc[k] :
                    (sprintf("\"%s\" %s", file, using))) ;

      if(title[k].nil?) then
#	com += sprintf("%s %s ls %d",plotObject,localstyle,styleCount) ;
	com += sprintf("%s %s lt %d",plotObject,localstyle,styleCount) ;
      else
#	com += sprintf("%s t \"%s\" %s ls %d",plotObject,
	com += sprintf("%s t \"%s\" %s lt %d",plotObject,
                       title[k],localstyle, styleCount) ;
      end

      # error bar
      if(@errbarstrm[k])
#        com += (", \"%s\" w yerrorbars ls %d notitle" % 
        com += (", \"%s\" w yerrorbars lt %d notitle" % 
                [@errbarfile[k],styleCount]) ;
      end
    }

    # plot horizontal lines.
    @hline.each{|line|
      label = line[0] ;
      value = line[1] ;
      style = (line[2].nil?) ? "dots" : line[2] ;

      com += (", %s title '%s' with %s" % [value.to_s, label, style]) ; 
      
    }

#    p [:plot, com] ;
    command(com) ;

    inlineDataList.each{|datafile|
      open(datafile){|strm|
        strm.each{|line|
          @strm << line ;
        }
      }
      @strm << "e\n" ;
    }

  end

  #------------------------------------------
  #++
  ## direct plot dgrid3d plot
  def dpDgrid3dPlotBegin()
    @dgrid3dPlotData = [] ;
  end

  #------------------------------------------
  #++
  ## direct plot dgrid3d plot
  def dpDgrid3dPlotEnd()
    self.command("$MyData << EOD") ;
    @dgrid3dPlotData.each{|xyz|
      self.command(xyz.join(" ")) ;
    }
    self.command("EOD") ;
  end
    
  #------------------------------------------
  #++
  ## direct plot dgrid3d plot
  def dpDgrid3dPlot(x,y,z)
    @dgrid3dPlotData.push([x,y,z]) ;
  end

end

#------------------------------------------------------------------------
#++
## direct ploting toplevel
def Gnuplot::directPlot(rangeopt = "", styles = Gnuplot::DfltPlotStyle) 
  gplot = Gnuplot::new() ;
  gplot.dpBegin() ;
  yield(gplot) ;
  gplot.dpEnd(true, rangeopt,styles) ;
  gplot.close() ;
end

#------------------------------------------------------------------------
#++
## direct multi ploting toplevel
def Gnuplot::directMultiPlot(m, rangeopt = "", 
			     styles = Gnuplot::DfltPlotStyle) 
  gplot = Gnuplot::new() ;
  gplot.dmpBegin(m) ;
  yield(gplot) ;
  gplot.dmpEnd(true, rangeopt,styles) ;
  gplot.close() ;
end

#------------------------------------------------------------------------
#++
## direct ploting toplevel
def Gnuplot::switchableDirectPlot(switch,	## true or false
                                  rangeopt = "", 
                                  styles = Gnuplot::DfltPlotStyle) 
  gplot = nil ;
  if(switch)
    gplot = Gnuplot::new() ;
    gplot.dpBegin() ;
  end

  yield(gplot) ;
  
  if(switch)
    gplot.dpEnd(true, rangeopt,styles) ;
    gplot.close() ;
  end
end

#------------------------------------------------------------------------
#++
## direct multi ploting toplevel
def Gnuplot::switchableDirectMultiPlot(switch, ## true or false
                                       m, 
                                       rangeopt = "", 
                                       styles = Gnuplot::DfltPlotStyle) 
  gplot = nil ;
  if(switch)
    gplot = Gnuplot::new() ;
    gplot.dmpBegin(m) ;
  end

  yield(gplot) ;
  
  if(switch)
    gplot.dmpEnd(true, rangeopt,styles) ;
    gplot.close() ;
  end
end

#------------------------------------------------------------------------
#++
## defaults for direct dgrid 3D ploting
Gnuplot::Dgrid3dPlotDefaultConf = {
  :pathBase => "./gnuplot",
  :title => nil,
  :xlabel => nil,
  :ylabel => nil,
  :zlabel => nil,
  :resolution => [100,100],
  :approxMode => :spline,
  :logscale => :xy, # nil, or :x, :y, :xy, :xyz, ...
  :contour => true, # 等高線
  :noztics => false,
  :view => [0,359.9999], # [0,0] だと、cblabel が ylabel とかぶる。
  :tgif => true,
}  

#------------------------------------------------------------------------
#++
## direct dgrid 3D ploting toplevel
def Gnuplot::directDgrid3dPlot(_conf = {}, &body)
  conf = Gnuplot::Dgrid3dPlotDefaultConf.dup.update(_conf) ;
  pathBase = conf[:pathBase] ;
  begin
    gplot = Gnuplot.new(:gplot, pathBase) ;
    
    gplot.setTitle(conf[:title]) if(conf[:title]) ;
    gplot.command("set xlabel \"#{conf[:xlabel]}\"") if(conf[:xlabel]) ;
    gplot.command("set ylabel \"#{conf[:ylabel]}\"") if(conf[:xlabel]) ;
    gplot.command("set ylabel rotate parallel") ;
    gplot.command("set dgrid3d #{conf[:resolution].join(",")} #{conf[:approxMode]}") ;
    gplot.command("set pm3d at b") ;
    gplot.command("set cblabel \"#{conf[:zlabel]}\" offset -10") if(conf[:zlabel]) ;
    gplot.command("set logscale #{conf[:logscale]}") if(conf[:logscale]) ;
    gplot.command("set contour") if(conf[:contour]) ;
    gplot.command("unset ztics") if(conf[:noztics]) ;
    gplot.command("set view #{conf[:view].join(",")}") ;
    gplot.dpDgrid3dPlotBegin() ;
    
    body.call(gplot) ;
    
    gplot.dpDgrid3dPlotEnd() ;
    gplot.command("splot $MyData u 1:2:3 w pm3d t '#{conf[:zlabel]}'") ;

    gplot.close() ;

#    gplot = Gnuplot.new("qt") ;
    gplot = Gnuplot.new("wxt") ;
    gplot.command("load \"#{pathBase}.gpl\"") ;
    
    if(conf[:tgif]) then
      gplot.setTerm(:tgif, "#{pathBase}") ;
      gplot.command("replot") ;
    end

    ensure
      gplot.close() if(gplot) ;
  end
    
end


######################################################################
######################################################################
######################################################################
if(__FILE__ == $0) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_GnuPlot < Test::Unit::TestCase

    #----------------------------------------------------
    #++
    ## show separator and title of the test.
    def setup
      #      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      name = "#{(@method_name||@__name__)}(#{self.class.name})" ;
      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      super
    end

    #----------------------------------------------------
    #++
    ## dynamic plot (flush)
    def test_a() ;
      gplot = Gnuplot::new("x11") ;
      gplot.dpBegin() ;
      range = "[0:10][0:100]" ;
      (0...100).each{|k|
        x = 0.1 * k ;
        gplot.dpXYPlot(x,x*x) ;
        gplot.dpFlush(range) ;
        sleep 0.01 ;
      }
      gplot.dpEnd(range) ;
      gplot.close() ;
    end

    #----------------------------------------------------
    #++
    ## dynamic multi plot (flush)
    def test_b() ;
      range = "[0:10][-1:1]" ;
      Gnuplot::directMultiPlot(3,range) {|gplot|
        gplot.dmpSetTitle(0,"foo") ;
        gplot.dmpSetTitle(1,"bar") ;
        gplot.dmpSetTitle(2,"baz") ;
        (0...100).each{|k|
          x = 0.1 * k ;
          gplot.dmpXYPlot(0,x,x*x) ;
          gplot.dmpXYPlot(1,x,Math::sin(x)) ;
          gplot.dmpXYPlot(2,x,Math::cos(x)) ;
          gplot.dmpFlush(range) ;
          sleep 0.1 ;
        }
      }
    end

    #----------------------------------------------------
    #++
    ## time format 
    def test_c() ;
      Gnuplot::directPlot("","w l"){|gplot|
        gplot.setTimeFormat(:x,"%Y-%m-%dT%H:%M") ;
        
        time = Time::now() ;
        (0...10).each{|i|
          x = time.strftime("%Y-%m-%dT%H:%M") ;
          y = rand(100) ;
          gplot.dpXYPlot(x,y) ;
          time += 10*60*60
        }
      }
    end

    #----------------------------------------------------
    #++
    ## time format 
    def test_d() ;
      Gnuplot::directMultiPlot([:a],"","w l"){|gplot|
        gplot.setTimeFormat(:x,"%Y-%m-%dT%H:%M","%d-%H") ;
        
        time = Time::now() ;
        (0...10).each{|i|
          x = time.strftime("%Y-%m-%dT%H:%M") ;
          y = rand(100) ;
          gplot.dmpXYPlot(:a,x,y) ;
          time += 10*60*60
        }
      }
    end

    #----------------------------------------------------
    #++
    ## error bar (single)
    def test_e() ;
      Gnuplot::directPlot("","w lp"){|gplot|
        (0...10).each{|i|
          x = i.to_f ;
          d = rand() * 10.0 ;
          yb = 0.4 * x * x + (d-5.0);
          r = rand(3) ;
          if(r > 1) then
            gplot.dpXYPlot(x, [yb, yb-d, yb+d*2]) ;
          elsif(r > 0) then
            gplot.dpXYPlot(x, [yb, d]) ;
          else
            gplot.dpXYPlot(x, yb) ;
          end
        }
      }
    end

    #----------------------------------------------------
    #++
    ## error bar (multi)
    def test_f() ;
      Gnuplot::directMultiPlot([:a,:b],"","w lp"){|gplot|
        (0...10).each{|i|
          x = i.to_f ;
          ya = x * x ;
          d = rand() * 10.0 ;
          yb = 0.4 * x * x + (d-5.0);
          gplot.dmpXYPlot(:a,x,ya) ;
          r = rand(3) ;
          if(r > 1) then
            gplot.dmpXYPlot(:b, x, [yb, yb-d, yb+d*2]) ;
          elsif(r > 0) then
            gplot.dmpXYPlot(:b, x, [yb, d]) ;
          else
            gplot.dmpXYPlot(:b, x, yb) ;
          end
        }
      }
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)


