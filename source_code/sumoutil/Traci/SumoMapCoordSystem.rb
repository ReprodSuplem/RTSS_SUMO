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
    ## coordinate system information.
    ## about X-Y coord.
    ##  X : west to east   (same as lon)
    ##  Y : south to north (same as lat)
    class CoordSystem
      #--::::::::::::::::::::::::::::::
      #++
      ## Proj command (projection converter)
      ProjCommand = "proj" ;
      InvProjCommand = "invproj -f '%.6f'" ;
      
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## offset in XY
      attr_accessor :offset ;
      ## bbox in XY
      attr_accessor :bboxXY ;
      ## bbox in lon-lat
      attr_accessor :bboxLonLat ;
      ## projection parameter 
      attr_accessor :projParam ;
      
      #--------------------------------
      #++
      ## initialize
      ## _xml_:: XML element
      def initialize(xml = nil)
        scanXml(xml) if(!xml.nil?) ;
      end

      #--------------------------------
      #++
      ## scan XML definition
      ## _xml_:: XML element : <location> element in <net> element.
      def scanXml(xml)
        _offset =
          SumoMap.getAttrVal(xml, "netOffset").split(',').map{|v| v.to_f} ;
        @offset = Geo2D::Point.sureGeoObj(_offset) ;

        _bboxXY =
          SumoMap.getAttrVal(xml, "convBoundary").split(',').map{|v| v.to_f} ;
        @bboxXY = Geo2D::Box.new(_bboxXY[0..1], _bboxXY[2..3]) 
          
        _bboxLonLat = 
          SumoMap.getAttrVal(xml, "origBoundary").split(',').map{|v| v.to_f} ;
        @bboxLonLat = Geo2D::Box.new(_bboxLonLat[0..1], _bboxLonLat[2..3]) ;

        @projParam = SumoMap.getAttrVal(xml, "projParameter") ;
        
        return self ;
      end

      #--------------------------------
      #++
      ## scan from NetXML Map File.
      ## _mapFile_:: map file whose suffix is .net.xml
      def scanFromNetXmlFile(_mapFile)
        _fparser = ItkXml::FilterParser.new(File.new(_mapFile)) ;
        _fparser.listenQName("location"){|_xml, _str|
          scanXml(_xml) ;
        }
        _fparser.parse ;
        return self ;
      end
      
      #--------------------------------
      #++
      ## convert to JSON object (hash)
      def toJson()
        json = { 'class' => self.class.to_s }
        json['netOffset'] = [@offset.x, @offset.y] ;
        json['convBoundary'] = [[@bboxXY.minPos.x, @bboxXY.minPos.y],
                                [@bboxXY.maxPos.x, @bboxXY.maxPos.y]] ;
        json['origBoundary'] = [[@bboxLonLat.minPos.x, @bboxLonLat.minPos.y],
                                [@bboxLonLat.maxPos.x, @bboxLonLat.maxPos.y]] ;
        json['projParameter'] = @projParam ;

        return json ;
      end
      
      #--------------------------------
      #++
      ## convert to JSON object (hash)
      ## _json_ :: JSON for one Lane.
      def scanJson(json)
        @offset = Geo2D::Point.sureGeoObj(json['netOffset']) ;

        _bboxXY = json['convBoundary'] ;
        @bboxXY = Geo2D::Box.new(*_bboxXY) ;
          
        _bboxLonLat = json['origBoundary'] ;
        @bboxLonLat = Geo2D::Box.new(*_bboxLonLat) ;

        @projParam = json['projParameter'] ;

        return self ;
      end

      #--------------------------------
      #++
      ## transpormation of coordinate system from LonLat to X-Y
      ## _lonlat_ :: longitude and latitude in Geo2D::Point object
      ## *return_ :: X-Y position in Geo2D::Point object
      def transformLonLat2XY(lonlat)
        lonlat = Geo2D::Point.sureGeoObj(lonlat) ;

        xyPos = nil ;
        com = "|echo #{lonlat.x} #{lonlat.y} | #{ProjCommand} #{@projParam}" ;

        open(com, 'r'){|strm|
          ret = strm.read().split("\s").map{|v| v.to_f} ;
          xyPos = Geo2D::Point.sureGeoObj(ret) ;
          xyPos.inc(@offset) ;
        }

        return xyPos ;
      end

      #--------------------------------
      #++
      ## transpormation of coordinate system from X-Y to LonLat 
      ## _xyPos_ :: X-Y position in Geo2D::Point object
      ## *return_ :: Lon-Lat position in Geo2D::Point object
      def transformXY2LonLat(xyPos)
        if(xyPos.is_a?(Array))
          xyPos = Geo2D::Point.sureGeoObj(xyPos) ;
        else
          xyPos = xyPos.dup() ;
        end
        xyPos.dec(@offset) ;

        lonlat = nil ;
        com = "|echo #{xyPos.x} #{xyPos.y} | #{InvProjCommand} #{@projParam}" ;

        open(com, 'r'){|strm|
          str = strm.read() ;
          ret = str.split("\s").map{|v| v.to_f} ;
          lonlat = Geo2D::Point.sureGeoObj(ret) ;
        }

        return lonlat ;
      end
      
    end # class CoordSystem
    
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
