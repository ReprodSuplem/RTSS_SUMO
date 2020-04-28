## -*- Mode: ruby -*-
##Header:
##Title: Generic 2D Geometrical Operations with Draw Facility
##Author: Anonymous3
##Date: 2005/11/18
##EndHeader:
##
##Usage:
#
##EndUsage:

require 'Geo2D.rb' ;
require 'myCanvas.rb' ;

######################################################################

module Geo2D

  ##============================================================
  ## utilities

  module Utility

    ##------------------------------------------------------------
    def lookupParam(paramTabList, key, defaultValue = nil)
      value = defaultValue ;
      paramTabList.each{|paramTab|
        if paramTab.key?(key) 
          value = paramTab[key] ;
          break ;
        end
      }
      value ;
    end

  end
  
  ##============================================================
  ## Point with Draw

  class Point

    ##----------------------------------------
    DrawParam = {
      :sizeAbs 	=> 2,
      :fillp 	=> true,
      :color 	=> 'black',
      nil	=> nil 
    } ;

    ##----------------------------------------
    def draw(canvas, *param)
      param.push(DrawParam) ;
      r = lookupParam(param,:sizeRel) ;
      if(r.nil?) then
        r = lookupParam(param,:sizeAbs).to_f / canvas.getScaleX() ;
      end
      canvas.drawCircle(@x, @y, r,
                        lookupParam(param, :fillp),
                        lookupParam(param, :color)) ;
      self ;
    end

  end

  ##============================================================
  ## LineSegment with Draw

  class LineSegment

    ##----------------------------------------
    DrawParam = {
      :width 	=> 1,
      :color 	=> 'black',
      nil	=> nil
    } ;

    ##----------------------------------------
    def draw(canvas, *param)
      param.push(DrawParam) ;
      canvas.drawSolidLine(@u.x, @u.y, @v.x, @v.y,
                           lookupParam(param, :width),
                           lookupParam(param, :color)) ;
      self ;
    end

  end

  ##============================================================
  ## LineStringr with Draw

  class LineString

    ##----------------------------------------
    DrawParam = {
      :width 	=> 1,
      :color 	=> 'black',
      nil	=> nil
    } ;

    ##----------------------------------------
    def draw(canvas, *param)
      param.push(DrawParam) ;
      width = lookupParam(param, :width) ;
      color = lookupParam(param, :color) ;
      eachLine{ |line|
        canvas.drawSolidLine(line.u.x, line.u.y, 
                             line.v.x, line.v.y,
                             width, color) ;
      }
      self ;
    end

  end

  ##============================================================
  ## Polygon with Draw

  class Polygon
    
    ##----------------------------------------
    DrawParam = {
      :fillColor => 'grey80',
      :frameColor => 'grey20',
      :drawInterior => true,
      :fillColorInterior => 'white',
      nil	=> nil } ;

    ##----------------------------------------
    def draw(canvas, *param)
      param.push(DrawParam) ;
      frameColor = lookupParam(param, :frameColor);
      fillColor = lookupParam(param, :fillColor);

      drawRing(@exterior, canvas, frameColor, fillColor) ;

      if(lookupParam(param, :drawInterior)) then
        fillColorInterior = lookupParam(param, :fillColorInterior);
        @interior.each{|ring|
          drawRing(ring, canvas, frameColor, fillColorInterior) ;
        }
      end

      self ;
    end

    ##----------------------------------------
    def drawRing(ring, canvas, frameColor, fillColor)
      posList = [] ;
      ring.eachPoint(){|point|
        posList.push([point.x, point.y]) ;
      }
      if(fillColor.nil?) then
        canvas.drawEmptyPolygon(posList, frameColor) ;
      else
        canvas.drawFramedPolygon(posList, frameColor, fillColor) ;
      end
      ring ;
    end

  end

  ##============================================================
  ## Collection

  class Collection < Array

    ##----------------------------------------
    def draw(canvas, *param)
      self.each{|geo|
        geo.draw(canvas, *param) ;
      }
      self ;
    end

  end



    
end

