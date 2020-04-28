#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Sumo Map Handler
## Author:: Anonymous3
## Version:: 0.0 2018/01/07 Anonymous3
##
## === History
## * [2018/01/07]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

require 'optparse' ;
require 'pp' ;
require 'json' ;

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");

require 'Geo2D.rb' ;
require 'RTree.rb' ;
require 'ItkXml.rb' ;

$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;
require 'ExpLogger.rb' ;

require 'TraciUtil.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## description of class Foo.
  class SumoMap < WithConfParam

    #--============================================================
    #--============================================================
    #++
    ## lane
    class Lane
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## id
      attr_accessor :id ;
      ## edge
      attr_accessor :edge ;
      ## index
      attr_accessor :index ;
      ## allow
      attr_accessor :allow ;
      ## disallow
      attr_accessor :disallow ;
      ## speed
      attr_accessor :speed ;
      ## length
      attr_accessor :length ;
      ## shape, a Geo2D::LineString
      attr_accessor :shape ;
      ## original ID in OSM
      attr_accessor :originalId ;
      
      #--------------------------------
      #++
      ## initialize
      ## _xml_:: XML element
      def initialize(xml = nil, edge = nil)
        scanXml(xml, edge) if(!xml.nil?) ;
      end
      
      #--------------------------------
      #++
      ## scan XML definition
      ## _xml_:: XML element
      def scanXml(xml, edge)
        @edge = edge ;
        
        @id = SumoMap.getAttrVal(xml, "id") ;
        @index = SumoMap.getAttrVal(xml, "index") ;
        
        disallowVal = SumoMap.getAttrVal(xml, "disallow") ;
        @disallow = disallowVal.split(' ').map{|v| v.intern} if(disallowVal) ;
          
        allowVal = SumoMap.getAttrVal(xml, "allow") ;
        @allow = allowVal.split(' ').map{|v| v.intern} if(allowVal) ;
          
        @speed = SumoMap.getAttrVal(xml, "speed").to_f ;
        @length = SumoMap.getAttrVal(xml, "length").to_f ;
        
        posList = SumoMap.getAttrVal(xml, "shape").split(' ') ;
        posList = posList.map{|xy| xy.split(',').map{|v| v.to_f}} ;
        @shape = Geo2D::LineString.new(posList) ;

        xml.each_element("param"){|param|
          if(param.attribute("key").to_s === "origId") then
            @originalId = param.attribute("value").to_s ;
          end
        }

        return self ;
      end

      #--------------------------------
      #++
      ## convert to JSON object (hash)
      def toJson()
        json = { 'class' => self.class.to_s }
        json['id'] = @id ;
        json['index'] = @index ;
        json['allow'] = @allow ;
        json['disallow'] = @disallow ;
        json['speed'] = @speed ;
        json['length'] = @length ;
        json['originalId'] = @originalId ;

        json['shape'] = genShapeJson() ;

        return json ;
      end
      
      #--------------------------------
      #++
      ## convert shape to JSON object (Array of point ([x, y])).
      def genShapeJson()
        shape = [] ;
        @shape.pointList.each{|point|
          pos = [point.x, point.y] ;
          shape.push(pos) ;
        }
        return shape ;
      end

      #--------------------------------
      #++
      ## convert to JSON object (hash)
      ## _json_ :: JSON for one Lane.
      def scanJson(json, edge)
        @edge = edge ;
        @id = json['id'] ;
        @index = json['index'] ;

        @allow = json['allow'] ;
        @allow = @allow.map{|v| v.intern} if(@allow) ;

        @disallow = json['disallow'] ;
        @disallow = @disallow.map{|v| v.intern} if(@disallow) ;

        @speed = json['speed'] ;
        @length = json['length' ] ;
        @originalId = json['originalId'] ;

        scanShapeJson(json['shape']) ;
        
        return self ;
      end

      #--------------------------------
      #++
      ## convert to JSON object (hash)
      ## _shapeJson_ :: a list of xy pair ([[x0, y0], [x1, y1], ...])
      def scanShapeJson(shapeJson)
        @shape = Geo2D::LineString.new(shapeJson) ;
      end
      
      #--------------------------------
      #++
      ## get GeoObject.
      ## used in RTree.
      ## *return* :: Geo2D::GeoObject for RTree
      def geoObject()
        return @shape ;
      end

      #--------------------------------
      #++
      ## get exit end of the lane
      ## *return* :: Geo2D::Point instance
      def getStartPoint()
        geoObject().firstPoint() ;
      end

      #--------------------------------
      #++
      ## get exit end of the lane
      ## *return* :: Geo2D::Point instance
      def getEndPoint()
        geoObject().lastPoint() ;
      end
      
      #--------------------------------
      #++
      ## get the foot point from the reference point.
      ## _reference_ :: reference point
      ## *return* :: Geo2D::Point of the foot point.
      def footPointFrom(reference)
        return geoObject().footPointFrom(reference) ;
      end

      #--------------------------------
      #++
      ## get the span of foot point from the reference point.
      ## _reference_ :: reference point
      ## *return* :: span
      def footPointSpanFrom(reference)
        span = geoObject().footPointSpanFrom(reference) ;
        span = length() if(span > length()) ;
        return span ;
      end

      #--------------------------------
      #++
      ## check permission for a certain type
      ## _type_ :: type symbol.  Nomally :private (private car).
      ## *return* :: true if has permission
      def checkPermissionFor(type = :private)
        
        if(!@allow.nil?) then # if included in @allow list, true.
          return @allow.include?(type) ;
        elsif(!@disallow.nil?) then # if included in @disallow list, false.
          return !(@disallow.include?(type)) ;
        else # no @allow or @disallow list, default is true ;
          return true ;
        end
      end

      #--------------------------------
      #++
      ## re-define inspect
      alias inspect_original inspect ;
      def inspect()
        dummy = self.dup ;
        dummy.remove_instance_variable('@edge') ;
        return dummy.inspect_original ;
      end
      
    end # class Lane

    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
    
  end # class SumoMap

end # module Sumo
  
########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'
  require 'TimeDuration.rb' ;

  #--============================================================
  #++
  ## unit test for this file.
  class TC_Foo < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleNetFile = "/home/noda/work/iss/SAVS/Data/2018.0104.Tsukuba/TsukubaCentral.small.net.xml" ;

    SampleJsonFile = '/tmp/SumoMap.tmp.json' ;
    SampleJsonFile2 = '/tmp/SumoMap.tmp2.json' ;

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
    ## scan XML file
    def test_a
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
