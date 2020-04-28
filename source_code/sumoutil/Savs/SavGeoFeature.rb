#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV Geo Feature
## Author:: Anonymous3
## Version:: 0.0 2018/08/25 Anonymous3
##
## === History
## * [2018/08/25]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'pp' ;

require 'WithConfParam.rb' ;
require 'SavUtil.rb' ;
require 'SumoMap.rb' ;
require 'SumoMapCoordSystem.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## ViaPoint
  class GeoFeature
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## original json
    attr_accessor :json ;
    ## name
    attr_accessor :name ;
    ## boundary box
    attr_accessor :bbox ;

    #--------------------------------------------------------------
    #++
    ## initialize
    def initialize(_json = {}, _map = nil)
      setup(_json, _map) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## setup
    def setup(_json, _map = nil)
      @json = _json ;
      setupName() ;      
      setupLocation(_map) if(!_map.nil?) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## setup name.
    def setupName()
      raise "not defined" ;
    end
    
    #--------------------------------------------------------------
    #++
    ## setup location data.
    def setupLocation(_map) 
      raise "not defined" ;
    end

    #--------------------------------------------------------------
    #++
    ## convert point location from lonlat to XY
    def convertLonLat2XY(lonlat, _map)
      _map.coordSystem.transformLonLat2XY(lonlat)
    end

    #--------------------------------------------------------------
    #++
    ## check inside or not
    def isInside(_pos)
      raise "not defined" ;
    end

    #--------------------------------------------------------------
    #++
    ## get random point inside
    def getRandomPoint()
      while(true)
        pos = @bbox.randomPoint() ;
        return pos if(isInside(pos)) ;
      end
    end
    
    #--============================================================
    #++
    ## PoI feature  (Sav::GeoFeature::PoI)
    class PoI < GeoFeature
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## position
      attr_accessor :pos ;
      ## position
      attr_accessor :lonlat ;

      #--------------------------------
      #++
      ## setup name
      def setupName()
        @name = @json[:tag][:"savs:poi"] ;
      end
      
      #--------------------------------
      #++
      ## setup location
      def setupLocation(_map)
        @lonlat = @json[:lonlat] ;
        @pos = convertLonLat2XY(@lonlat,_map) ;
      end
      
    end # class Sav::GeoFeature::PoI < GeoFeature
    
    #--============================================================
    #++
    ## Zone feature  (Sav::GeoFeature::Zone)
    class Zone < GeoFeature
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## shape
      attr_accessor :shape ;
      ## position
      attr_accessor :lonlat ;

      #--------------------------------
      #++
      ## setup name
      def setupName()
        @name = @json[:tag][:"savs:zone"] ;
      end
      
      #--------------------------------
      #++
      ## setup location
      def setupLocation(_map)
        @lonlat = @json[:lonlat] ;
        exterior = [] ;
        @lonlat.each{|ll|
          pos = convertLonLat2XY(ll,_map) ;
          exterior.push(pos) ;
        }
        @shape = Geo2D::Polygon.new(exterior) ;
        @bbox = @shape.bbox() ;
      end

      #--------------------------------
      #++
      ## check inside or not
      def isInside(_pos)
        return @shape.insidePoint?(_pos) ;
      end

    end # class Sav::GeoFeature::Zone < GeoFeature

    #--============================================================
    #++
    ## Circle feature  (Sav::GeoFeature::Circle)
    class Circle < GeoFeature
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## center
      attr_accessor :center ; # PoI or Geo2D::Point
      ## radius
      attr_accessor :radius ;

      #--------------------------------
      #++
      ## initialize
      def initialize(_center, _radius)
        @center = _center ;
        if(@center.is_a?(Array)) then
          @center = Geo2D::Point::sureGeoObj(@center) ;
        end
        
        @radius = _radius ;

        _pos = centerPos() ;
        @bbox = Geo2D::Box::new([_pos.x - @radius, _pos.y - @radius],
                                [_pos.x + @radius, _pos.y + @radius]) ;
      end
      
      #--------------------------------
      #++
      ## center
      def centerPos()
        if(@center.is_a?(PoI)) then
          return @center.pos ;
        else
          return @center ;
        end
      end
      
      #--------------------------------
      #++
      ## check inside or not
      def isInside(_pos)
        _pos = Geo2D::Point::sureGeoObj(_pos) ;
        distance = centerPos().distanceTo(_pos) ;
        return distance < @radius ;
      end
      
    end # class Sav::GeoFeature::Circle < GeoFeature

    #--============================================================
    #++
    ## List feature  (Sav::GeoFeature::List)
    class List < GeoFeature
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## list
      attr_accessor :list ; # list of GeoFeature

      #--------------------------------
      #++
      ## initialize
      def initialize(_name, _list)
        @name = _name ;
        @list = _list ;
        calcBBox() ;
      end
      
      #--------------------------------
      #++
      ## check inside
      def isInside(_pos) 
        @list.each{|feature|
          return true if(feature.isInside(_pos)) ;
        }
        return false ;
      end
      
      #--------------------------------
      #++
      ## get random point inside
      def getRandomPoint()
        feature = @list.sample() ;
        return feature.getRandomPoint() ;
      end
      
      #--------------------------------
      #++
      ## calc bbox
      def calcBBox()
        @bbox = @list.first.bbox() ;
        
        @list.each{|feature|
          @bbox.insert(feature.bbox()) ;
        }
        return @bbox ;
      end
      
    end # class Sav::GeoFeature::List < GeoFeature
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class GeoFeature
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavGeoFeature < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    TestData = nil ;

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
    ## about test_a
    def test_a
      pp [:test_a] ;
      assert_equal("foo-",:foo.to_s) ;
    end

  end # class TC_SavsGeoFeature
end # if($0 == __FILE__)
