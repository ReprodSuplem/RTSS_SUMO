#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Savs Log Entry class
## Author:: Anonymous3
## Version:: 0.0 2018/12/23 Anonymous3
##
## === History
## * [2018/12/23]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

#--======================================================================
#++
## SavsLog handling class. (dummy)
class SavsLogEntry
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## original info in csv ;
    attr_accessor :csv ;
    ## scanned table
    attr_accessor :table ;
    
    #--========================================
    #------------------------------------------
    #++
    ## BusStopTable の設定。
    def self.setBusStopTable(_table)
      @@busStopTable = _table ;
    end
    
    #------------------------------------------
    #++
    ## 初期化。
    def initialize()
    end

    #------------------------------------------
    #++
    ## access to value
    def getValue(key)
      return @table[key] ;
    end

    #------------------------------------------
    #++
    ## get pickUp bus stop id.
    def getPickUpBusStop()
      stop = @@busStopTable.getStopByName(getValue(:pickUpPoint)) ;
      if(stop.nil?) then
        raise "wrong bus stop: #{getValue(:pickUpPoint)}"
      end
      return stop ;
    end
      
    #------------------------------------------
    #++
    ## get dropOff bus stop id.
    def getDropOffBusStop()
      stop = @@busStopTable.getStopByName(getValue(:dropOffPoint)) ;
      if(stop.nil?) then
        raise "wrong bus stop: #{getValue(:dropOffPoint)}"
      end
      return stop ;
    end
      
    #------------------------------------------
    #++
    ## check valid data.
    def isValid()
      return !getValue(:demandId).nil? && getValue(:submitTime) ;
    end

    #------------------------------------------
    #++
    ## CSV row scan.
    ## 
    def scanCsvRow(_row, _keyList, _colIndex)
      @csv = _row ;
      @table =
        SavsLog.scanCsvRowToTable(_row, _keyList, _colIndex,
                                  SavsLog::KeyMap) ;
      return self ;
    end

    #------------------------------------------
    #++
    ## convert to Json
    ## 
    def toJson()
      return @table ;
    end

    #------------------------------------------
    #++
    ## convert to Json Strng
    ## 
    def toJsonString(prettyP = false)
      _json = toJson() ;
      if(prettyP) then
        return JSON.pretty_generate(_json) ;
      else
        return JSON.generate(_json) ;
      end
    end

    #------------------------------------------
    #++
    ## scan Json Object
    ## 
    def scanJson(_json)
      @table = _json.dup ;
      @table.each{|_key, _value|
        (_,_type) = *(SavsLog::KeyMap[_key]) ;
        _v = SavsLog.convertValueByType(_value, _type) ;
        @table[_key] = _v ;
      }
      return self ;
    end

end # class SavLog


