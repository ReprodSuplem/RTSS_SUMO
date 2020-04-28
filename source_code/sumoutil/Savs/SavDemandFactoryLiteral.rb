#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Random Demand Factory
## Author:: Anonymous3
## Version:: 0.0 2019/03/15 Anonymous3
##
## === History
## * [2019/03/15]: Create This File.
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
require 'time' ;

require 'SavDemandFactory.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Factory of SavDemandLiteral.
  ## ファイル等で与えられたデマンドをそのままデマンドとする。
  ## The config (demandConfig) param should be in the following format:
  ##  <Config> ::= {
  ##                 dataMode: [ :file | :list ],
  ##                 fileType: [ :json ],
  ##                 dataFile: "DataFile.json",
  ##                 mapFile: "Map.net.xml",
  ##                 defaultNumPassenger: 1, 2, ...
  ##                 timeOrigin: "YYYY-MM-DD HH:MM:SS +0900",
  ##                 timeTerminus: "YYYY-MM-DD HH:MM:SS +0900",
  ##                 walkSpeed: 1.0
  ##               }
  class SavDemandFactoryLiteral < SavDemandFactory
    
    #--============================================================
    ## register the class as a components of the Mixture.
    SavDemandFactoryMixture.registerFactoryType("literal", self) ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## Default Conf for WithConfParam
    DefaultConf = { } ;

    ## default conf in config entry in the demand.json.
    DefaultDemandConf = {
      :dataMode => :file,  # or :list. specify where is the data.
      :fileType => :json,   # or :csv.  specify file format of literal data.
      :dataFile => nil,
      :mapFile => nil,
      :defaultNumPassenger => 1,
      :timeOrigin => "2019-01-01 09:00:00 +0900",
      :timeUntil => "2019-01-01 21:00:00 +0900",
      :walkSpeed => 3.0 * 1000 / 60 / 60, # 平均歩行速度
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## config 
    attr_accessor :demandConf ;
    ## remaining demand list
    attr_accessor :futureDemandList ;
    ## 時間起点 (in Time)
    attr_accessor :timeOrigin ;
    ## 時間終点 (in sec)
    attr_accessor :timeUntil ;
    ## 座標変換
    attr_accessor :coordSystem ;
    ## 歩行速度
    attr_accessor :walkSpeed ;
    
    #------------------------------------------
    #++
    ## setup.d
    def setup()
      super() ;
      @demandConf = DefaultDemandConf.dup.update(getConf(:config)) ;
      @walkSpeed = @demandConf[:walkSpeed] ;
      setupTimeRange() ;
      setupMapCoordSystem() ;
      setupDemandList() ;
    end
    
    #------------------------------------------
    #++
    ## setup time range
    def setupTimeRange()
      @timeOrigin = Time.parse(@demandConf[:timeOrigin]) ;
      @timeUntil = Time.parse(@demandConf[:timeUntil]) ;
    end
    
    #------------------------------------------
    #++
    ## setup map coordinate system
    def setupMapCoordSystem()
      _mapFile = @demandConf[:mapFile] ;
      if(_mapFile) then
        @coordSystem = Sumo::SumoMap::CoordSystem.new() ;
        @coordSystem.scanFromNetXmlFile(_mapFile) ;
      end
      return @coordSystem ;
    end
    
    #------------------------------------------
    #++
    ## setup demand list from file.
    def setupDemandList()
      case(@demandConf[:dataMode].intern)
      when :file
        setupDemandListFromFile() ;
      else
        raise "unknown data mode:" + @demandConf[:dataMode].to_s ;
      end
    end
    
    #------------------------------------------
    #++
    ## setup demand list from file.
    def setupDemandListFromFile()
      @futureDemandList = [] ;
      
      _file = @demandConf[:dataFile] ;
      _type = @demandConf[:fileType] ;
      
      case(_type.intern) ;
      when :json ;
        readDemandListFromFile_json(_file) ;
      when :csv ;
        readDemandListFromFile_csv(_file) ;
      else
        raise "unknown data type: " + _type.to_s ;
      end
    end

    #------------------------------------------
    #++
    ## setup demand list from JSON file.
    ## FileFormat ::= '[' Demand, Demand, ... ']'
    ## Demand ::= '{'
    ##   "submitTime":"YYYY-MM-DD HH:MM:SS +0900",
    ##   "demandId":null,
    ##   "requestType":null,
    ##   "userUniqueId":NNNN,
    ##   "passengerId":null,
    ##   "savId":null,
    ##   "nPassenger":N,
    ##   "cancelTime":null,
    ##   "pickUpTime":null,
    ##   "dropOffTime":null,
    ##   "pickUpLatLon":[Lat, Lon],
    ##   "pickUpXYPos":[X, Y],
    ##   "pickUpPoint":null,
    ##   "dropOffLatLon":[Lat, Lon],
    ##   "dropOffXYPos":[X, Y],
    ##   "dropOffPoint":null,
    ##   "pickUpPlannedTimeInit":null,
    ##   "pickUpPlannedTimeFinal":null,
    ##   "dropOffPlannedTimeInit":null,
    ##   "dropOffPlannedTimeFinal":null,
    ##   "pickUpRequiredTime":"YYYY-MM-DD HH:MM:SS +0900" (or null),
    ##   "dropOffRequiredTime":"YYYY-MM-DD HH:MM:SS +0900" (or null),
    ##   '}'
    ##   null の項目は存在する必要はない。（これまでのデータとのコンパチのため）
    def readDemandListFromFile_json(_file)
      open(_file, "r"){|strm|
        _json = JSON.parse(strm.read(), {:symbolize_names => true}) ;
        setupDemandListFromJson(_json) ;
      }
    end
    
    #------------------------------------------
    #++
    ## setup demand list from JSON
    def setupDemandListFromJson(_json)
      _json.each{|_demandJson|
        _demand = scanDemandJson(_demandJson) ;
        @futureDemandList.push(_demand) if(_demand) ;
      }
    end
    
    #------------------------------------------
    #++
    ## scan JSON as a demand and check availability (in TimeRange).
    def scanDemandJson(_json)
      _submitTime = scanTimeEntry(_json, :submitTime) ;
      
      if(@timeOrigin < _submitTime && _submitTime < @timeUntil) then
        _json[:submitTime] = _submitTime ;
        _json[:pickUpRequiredTime] = scanTimeEntry(_json, :pickUpRequiredTime) ;
        _json[:dropOffRequiredTime] = scanTimeEntry(_json,
                                                    :dropOffRequiredTime) ;
        _json[:submitSimTime] = _submitTime - @timeOrigin ;
        if(@coordSystem) then
          if(_json[:pickUpXYPos].nil?) then
            _latlon = _json[:pickUpLatLon] ;
            _json[:pickUpXYPos] =
              @coordSystem.transformLonLat2XY([_latlon[1], _latlon[0]]) ;
          end
          if(_json[:dropOffXYPos].nil?) then
            _latlon = _json[:dropOffLatLon] ;
            _json[:dropOffXYPos] =
              @coordSystem.transformLonLat2XY([_latlon[1], _latlon[0]]) ;
          end
        end
        return _json ;
      else
        return nil ;
      end
    end
    
    #------------------------------------------
    #++
    ## scan Time Entry
    def scanTimeEntry(_json, _key)
      _str = _json[_key] ;
      if(_str.nil?) then
        return nil ;
      else
        return Time.parse(_str) ;
      end
    end
    
    #------------------------------------------
    #++
    ## setup demand list from CSV file.
    def setupDemandListFromFile_csv(_file)
      raise "not implemented yet."
    end
    
    #------------------------------------------
    #++
    ## generate new demand() ;
    def newDemand()
      return nil if(@futureDemandList.empty?()) ;
      
      _demand = @futureDemandList.first() ;
      return nil if(_demand[:submitSimTime] > @simulator.currentTime) ;
      
      @futureDemandList.shift() ;

      _pickUpPos = _demand[:pickUpXYPos] ;
      _dropOffPos = _demand[:dropOffXYPos] ;

      _passenger = _demand[:passengerId].to_s ;
      _numPassenger = _demand[:nPassenger] ;

      _newDemand = Sav::SavDemand.new(_passenger, _numPassenger,
                                      Trip.new(_pickUpPos, _dropOffPos),
                                      @simulator,
                                      @demandConf) ;

      ## 締め切り時刻設定
      if(_demand[:dropOffRequiedTime]) then
        _deadLine = _demand[:dropOffRequiedTime] - @timeOrigin ;
      else
        _aveDist = Sav::Util.averageManhattanDistance(_pickUpPos, _dropOffPos) ;
        _deadLine = @simulator.currentTime + _aveDist / @walkSpeed ;
      end
      _newDemand.tripRequiredTime.dropOff = _deadLine ;

      return _newDemand ;
    end
    
    #------------------------------------------
    #++
    ## generate new demands in a cycle
    def newDemandListForCycle()
      _list = [] ;
      while(_newDemand = newDemand())
        _list.push(_newDemand) ;
      end

      return _list ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandFactoryLiteral
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavBase < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleDirBase = "/home/noda/work/iss/SAVS/Data" ;
    SampleDir = "#{SampleDirBase}/2018.0104.Tsukuba"
    SampleConfFile03 = "#{SampleDir}/tsukuba.03.sumocfg" ;

    SampleXmlMapFile = "#{SampleDir}/TsukubaCentral.small.net.xml" ;
    SampleJsonMapFile = SampleXmlMapFile.gsub(/.xml$/,".json") ;

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
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
