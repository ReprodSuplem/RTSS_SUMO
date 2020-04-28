#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Traci Data Types
## Author:: Anonymous3
## Version:: 0.0 2014/07/03 Anonymous3
##
## === History
## * [2014/07/03]: Separate from TraciClient.rb
## == Usage
## * ...

require 'pp' ;
require 'socket' ;
require 'singleton' ;

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;

require 'TraciUtil.rb' ;
require 'TraciConstants.rb' ;


#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## module for Traci
  module Traci

    #--============================================================
    #++
    ## DataType
    class DataType < Util::NamedIdEntry
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## size in message. if nil, it can be variable.
      attr :size, true ;
      ## template used in pack and unpack
      attr :packTemplate, true ;
      ## components. if nil, it is atomic type.
      attr :components, true ;

      #----------------------------------------------------
      #++
      ## initialization
      ## _name_:: name of data type. should be Symbol.
      ## _cname_:: name in Constant table. should be String.
      ## _size_:: size in message.
      ## _packTemp_:: template for pack/unpack
      ## _components_:: components
      def initialize(name, cname, size, packTemp, components = nil)
        super
        @size = size ;
        @packTemplate = packTemp ;
        @components = components ;
      end

      #----------------------------------------------------
      #++
      ## slice and unpack data from a byte string
      ## _buffer_:: buffer
      ## *return*:: scanned value
      def unpack!(buffer)
        case(@packTemplate)
        when(:composed)
          return unpackComposed!(buffer) ;
        when(:composedList)
          return unpackComposedList!(buffer) ;
        when(nil)
          raise("no pack template are given:" + 
                self.inspect) ;
        else
          return buffer.slice!(0,@size).unpack(@packTemplate).first() ;
        end
      end

      #----------------------------------------------------
      #++
      ## slice and unpack composed data from a byte string
      ## _buffer_:: buffer
      ## *return*:: scanned value. a Hash instance.
      def unpackComposed!(buffer)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
        value = { :dataType => self.class.name } ;
        @components.each{|slot|
          (slotName, slotType) = slot ;
          slotTypeDef = DataTypeTable.getByName(slotType) ;
          raise("unknown data type is specified in composed type" +
                [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
          value[slotName] = slotTypeDef.unpack!(buffer) ;
        }
        return value ;
      end

      #----------------------------------------------------
      #++
      ## slice and unpack composed data list from a byte string
      ## _buffer_:: buffer
      ## *return*:: scanned value. an Array with @dataType instance variable.
      def unpackComposedList!(buffer)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
#        value = { :dataType => self.class.name } ;  ## value is Array.
        value = [] ;
        value.instance_eval{@dataType = self.class.name}
        # here, we assume @components = [<lengthDef>, [<slot1>,<slot2>...]]

        # read length
        (lenName,lenType) = @components[0] ;
        lenTypeDef = DataTypeTable.getByName(lenType) ;
        len = lenTypeDef.unpack!(buffer) ;

        # read elements
        elementsDef = @components[1] ;
        (0...len).each{|i|
          element = {} ;
          elementsDef.each{|slot|
            (slotName, slotType) = slot ;
            slotTypeDef = DataTypeTable.getByName(slotType) ;
            raise("unknown data type is specified in composed type" +
                  [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
            element[slotName] = slotTypeDef.unpack!(buffer) ;
          }
          value.push{element} ;
        }
        return value ;
      end

      #----------------------------------------------------
      #++
      ## actual size of value
      ## _value_:: the data to encode
      ## *return*:: actual length of packed data
      def actualSize(value)
        case(@packTemplate)
        when(:composed)
          return actualSizeComposed(value) ;
        when(:composedList)
          return actualSizeComposedList(value) ;
        when(nil)
          raise("no pack template are given:" + 
                self.inspect) ;
        else
          return @size ;
        end
      end

      #----------------------------------------------------
      #++
      ## actual size for composed data
      ## _value_:: value. should be a hash table
      ## *return*:: length of packed data
      def actualSizeComposed(value)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
        sz = 0 ;
        @components.each{|slot|
          (slotName, slotType) = slot ;
          slotTypeDef = DataTypeTable.getByName(slotType) ;
          raise("unknown data type is specified in composed type" +
                [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
          slotValue = value[slotName] ;
          raise("slot value is not specified. " +
                [slotName, value].inspect) if(slotValue.nil?) ;
          sz += slotTypeDef.actualSize(slotValue) ;
        }
        return sz ;
      end

      #----------------------------------------------------
      #++
      ## actual size for composed list 
      ## _value_:: value. should be a list of data
      ## *return*:: length of packed data
      def actualSizeComposedList(value)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
        sz = 0 ;
        # here, we assume @components = [<lengthDef>, [<slot1>,<slot2>...]]

        # length part
        (lenName,lenType) = @components[0] ;
        lenTypeDef = DataTypeTable.getByName(lenType) ;
        sz += lenTypeDef.actualSize(value.length) ;

        # elements part
        elementsDef = @components[1] ;
        value.each{|v|
          elementsDef.each{|slot|
            (slotName, slotType) = slot ;
            slotTypeDef = DataTypeTable.getByName(slotType) ;
            raise("unknown data type is specified in composed type" +
                  [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
            sz += slotTypeDef.actualSize(v) ;
          }
        }
        return sz ;
      end

      #----------------------------------------------------
      #++
      ## pack value to byte string
      ## _value_:: value
      ## _withTypeTag_:: if true, pack with value type byte at head.
      ## *return*:: packed string
      def pack(value, withTypeTag = false)
        case(@packTemplate)
        when(:composed) # pack without type tag in components
          return packComposed(value, withTypeTag) ;
        when(:composedList)
          return packComposedList(value, withTypeTag) ;
        when(:compound) # pack with type tag in components
          return packCompound(value, withTypeTag) ;
        when(nil)
          raise("no pack template are given:" + 
                self.inspect) ;
        else
          if(withTypeTag)
            return [@id,value].pack("C"+@packTemplate) ;
          else
            return [value].pack(@packTemplate) ;
          end
        end
      end

      #----------------------------------------------------
      #++
      ## pack composed value to byte string
      ## _value_:: value to pack. should be a hash
      ## *return*:: packed byte string
      def packComposed(value, withTypeTag = false)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
        packedList = [] ;
        packedList.push(DataType_UByte.pack(@id)) if(withTypeTag) ;

        @components.each{|slot|
          (slotName, slotType) = slot ;
          slotTypeDef = DataTypeTable.getByName(slotType) ;
          raise("unknown data type is specified in composed type" +
                [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
          packedList.push(slotTypeDef.pack(value[slotName])) ;
        }
        return packedList.join ;
      end

      #----------------------------------------------------
      #++
      ## pack composed value list to a byte string
      ## _value_:: value. should be a list of hash
      ## *return*:: packed byte string
      def packComposedList(value, withTypeTag = false)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
        packedList = [] ;
        packedList.push(DataType_UByte.pack(@id)) if(withTypeTag) ;

        # here, we assume @components = [<lengthDef>, [<slot1>,<slot2>...]]
        # read length
        (lenName,lenType) = @components[0] ;
        lenTypeDef = DataTypeTable.getByName(lenType) ;
        packedList.push(lenTypeDef.pack(value.size)) ;

        # read elements
        elementsDef = @components[1] ;
        value.each{|v|
          elementsDef.each{|slot|
            (slotName, slotType) = slot ;
            slotTypeDef = DataTypeTable.getByName(slotType) ;
            raise("unknown data type is specified in composed type" +
                  [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
            packedList.push(slotTypeDef.pack(v[slotName])) ;
          }
        }
        return packedList.join ;
      end

      #----------------------------------------------------
      #++
      ## pack compound value list to a byte string
      ## _value_:: value. should be an Array or Hash of data
      ##           [val1, val2, val3...] or
      ##           { :slot1 => val1, :slot2 => val2, ...}
      ## *return*:: packed byte string
      def packCompound(value, withTypeTag = false)
        raise("components are not given for DataType:" +
              self.inspect) if(@components.nil?) ;
        raise("too many components for the template:" +
              value.inspect + " for " +
              self.inspect + ".") if(value.size > @components.size) ;

        #prepare header part.
        packedList = [] ;
        packedList.push(DataType_UByte.pack(DataType_Compound.id)) if(withTypeTag);
        packedList.push(DataType_Integer.pack(value.size)) ;

        #add body part.
        (0...value.size).each{|i|
          slot = @components[i] ;
          (slotName, slotType) = slot ;
          slotTypeDef = DataTypeTable.getByName(slotType) ;
          raise("unknown data type is specified in composed type" +
                [slotName, slotType].inspect) if(slotTypeDef.nil?) ;
          val = (value.is_a?(Hash) ? value[slotName] : value[i]) ;
          packedList.push(slotTypeDef.pack(value[slotName], true)) ;
        }
        return packedList.join ;
      end

    end # class DataType

    #--============================================================
    #++
    ## Table for DataType
    class DataTypeTable < Util::NamedIdTable
      def entryClass
        DataType
      end
    end # class DataTypeTable

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## Traci Data Type Table definitions
    ## (for atomic)
    DataTypeTable.add(:ubyte 	, "TYPE_UBYTE", 1, "C") ;
    DataTypeTable.add(:byte  	, "TYPE_BYTE", 1, "c") ;
    DataTypeTable.add(:integer	, "TYPE_INTEGER", 4, "N") ;
    DataTypeTable.add(:float	, "TYPE_FLOAT", 4, "g") ;
    DataTypeTable.add(:double	, "TYPE_DOUBLE", 8, "G") ;
    DataTypeTable.add(:string	, "TYPE_STRING", nil, :string) ;
    DataTypeTable.add(:stringList, "TYPE_STRINGLIST", nil, :stringList) ;
    DataTypeTable.add(:compound	, "TYPE_COMPOUND", nil, nil) ;

    ## (for composed)
    DataTypeTable.add(:pos2D	, "POSITION_2D", 
                      nil, :composed,
                      [[:x, :double], [:y,:double]]) ;
    DataTypeTable.add(:pos3D	, "POSITION_3D", 
                      nil, :composed,
                      [[:x, :double], [:y,:double], [:z,:double]]) ;
    DataTypeTable.add(:posRoadMap,"POSITION_ROADMAP", 
                      nil, :composed,
                      [[:roadId, :string], [:pos, :double], 
                       [:laneId, :ubyte]]) ;
    DataTypeTable.add(:posLonLat, "POSITION_LON_LAT", 
                      nil, :composed,
                      [[:longitude, :double], [:latitude, :double]]) ;
    DataTypeTable.add(:poslonLatAlt,"POSITION_LON_LAT_ALT", 
                      nil, :composed,
                      [[:longitude, :double], [:latitude, :double],
                       [:altitude, :double]]) ;
    DataTypeTable.add(:boundaryBox, "TYPE_BOUNDINGBOX", 
                      nil, :composed,
                      [[:lowerLeftX, :double],[:lowerLeftY, :double],
                       [:upperRightX, :double], [:upperRightY, :double]]) ;
    DataTypeTable.add(:polygon, "TYPE_POLYGON", 
                      nil, :composedList,
                      [[:length, :ubyte], 
                       [[:x, :double],[:y, :double]]]) ;
    DataTypeTable.add(:trafficLightPhaseList , "TYPE_TLPHASELIST", 
                      nil, :composedList,
                      [[:length, :ubyte],
                       [[:precRoad, :string], [:succRoad, :string],
                        [:phase, :ubyte]]]) ;
    DataTypeTable.add(:color, "TYPE_COLOR", 
                      nil, :composed,
                      [[:r, :ubyte], [:g, :ubyte], [:b, :ubyte], 
                       [:a, :ubyte]]) ;
    ## (for compound) for SetVariable :vehicle.
    DataTypeTable.add(:compoundNil, -1,
                      nil, :compound,
                      []) ;
    DataTypeTable.add(:arg4Stop0, "CMD_STOP",
                      nil, :compound,
                      [[:edgeId, :string], [:position, :double], 
                       [:laneIndex, :byte], 
                       [:duration, :integer], # [msec]
                      ]) ;
    DataTypeTable.add(:arg4Stop1, "CMD_STOP",
                      nil, :compound,
                      [[:edgeId, :string], [:position, :double], 
                       [:laneIndex, :byte], 
                       [:duration, :integer], # [msec]
                       [:stopFlag, :byte], # See StopFlagBitTable.
                      ]) ;
    DataTypeTable.add(:arg4Stop2, "CMD_STOP",
                      nil, :compound,
                      [[:edgeId, :string], [:position, :double], 
                       [:laneIndex, :byte], 
                       [:duration, :integer], # [msec]
                       [:startPosition, :double], # restart position
                      ]) ;
    DataTypeTable.add(:arg4Stop3, "CMD_STOP",
                      nil, :compound,
                      [[:edgeId, :string], [:position, :double], 
                       [:laneIndex, :byte], 
                       [:duration, :integer], # [msec]
                       [:until, :integer], # until in msec.
                      ]) ;
    DataTypeTable.add(:arg4ChangeLane, "CMD_CHANGELANE",
                      nil, :compound,
                      [[:laneIndex, :byte],
                       [:duration, :integer] # [msec]
                      ]) ;
    DataTypeTable.add(:arg4SlowDown, "CMD_SLOWDOWN",
                      nil, :compound,
                      [[:speed, :double],
                       [:duration, :integer] # [msec]
                      ]) ;
    DataTypeTable.add(:arg4Resume, "CMD_RESUME",
                      nil, :compound,
                      []) ;
    DataTypeTable.add(:arg4ChangeEdgeTravelTime4, "VAR_EDGE_TRAVELTIME",
                      nil, :compound,
                      [[:beginTime, :integer], # [sec]
                       [:endTime, :integer], # [sec]
                       [:edgeId, :string],
                       [:travelTime, :double], # [sec]
                      ]) ;
    DataTypeTable.addExtra(:arg4ChangeEdgeTravelTime2, "VAR_EDGE_TRAVELTIME",
                           nil, :compound,
                           [[:edgeId, :string],
                            [:travelTime, :double], # [sec]
                           ]) ;
    DataTypeTable.addExtra(:arg4ChangeEdgeTravelTime1, "VAR_EDGE_TRAVELTIME",
                           nil, :compound,
                           [[:edgeId, :string]]) ;
    DataTypeTable.add(:arg4ChangeEdgeEffort4, "VAR_EDGE_EFFORT",
                      nil, :compound,
                      [[:beginTime, :integer], # [sec]
                       [:endTime, :integer], # [sec]
                       [:edgeId, :string],
                       [:effort, :double], 
                      ]) ;
    DataTypeTable.addExtra(:arg4ChangeEdgeEffort2, "VAR_EDGE_EFFORT",
                           nil, :compound,
                           [[:edgeId, :string],
                            [:effort, :double], 
                           ]) ;
    DataTypeTable.addExtra(:arg4ChangeEdgeEffort1, "VAR_EDGE_EFFORT",
                           nil, :compound,
                           [[:edgeId, :string]]) ;
    DataTypeTable.add(:arg4MoveTo, "VAR_MOVE_TO",
                      nil, :compound,
                      [[:laneId, :string], # ??? lane ID は :string か :ubyte か
                       [:position, :double]]) ;
    ### DataTypeTable.add(:arg4RerouteTravelTime, "CMD_REROUTE_TRAVELTIME",
    ###                  nil, :compound,
    ###                  []) ;  # use :compoundNil
    ### DataTypeTable.add(:arg4RerouteEffort0, "CMD_REROUTE_EFFORT",
    ###                   nil, :compound,
    ###                  []) ;  # use :compoundNil
    DataTypeTable.add(:arg4RerouteEffort2, "CMD_REROUTE_EFFORT",
                      nil, :compound,
                      [[:laneId, :string],
                       [:position, :double]]) ;
    DataTypeTable.add(:arg4Add, "ADD",
                      nil, :compound,
                      [[:vehicleTypeId, :string],
                       [:routeId, :string],
                       [:departTime, :integer],
                       [:departPosition, :double],
                       [:departSpeed, :double],
#                       [:departLane, :ubyte]]) ;
                       [:departLane, :byte]]) ;
    DataTypeTable.add(:arg4AddFull, "ADD_FULL",
                      nil, :compound,
                      [[:routeId, :string],
                       [:vehicleTypeId, :string],
                       [:departTime, :string], # ??? :integer?
                       [:departLane, :string], # ??? :ubyte?
                       [:departPosition, :string], # ??? :double?
                       [:departSpeed, :string], # ??? :double?
                       [:arrivalLane, :string], # ??? ubyte?
                       [:arrivalPosition, :string], # ??? :double?
                       [:arrivalSpeed, :string], 
                       [:fromTaz, :string],
                       [:toTaz, :string],
                       [:line, :string],
                       [:personCapacity, :integer],
                       [:personNumber, :integer]]) ;
    # PoI
    DataTypeTable.add(:arg4AddPoi, "ADD",
                      nil, :compound,
                      [[:type, :string],
                       [:color, :color],
                       [:layer, :integer],
                       [:position, :pos2D]]) ;
    ## short cut
    DataType_UByte = DataTypeTable.getByName(:ubyte) ;
    DataType_Byte = DataTypeTable.getByName(:byte) ;
    DataType_Integer = DataTypeTable.getByName(:integer) ;
    DataType_Float = DataTypeTable.getByName(:float) ;
    DataType_Double = DataTypeTable.getByName(:double) ;
    DataType_String = DataTypeTable.getByName(:string) ;
    DataType_StringList = DataTypeTable.getByName(:stringList) ;
    DataType_Compound = DataTypeTable.getByName(:compound) ;

    #--------------------------------------------------------------
    #++
    ## string unpack
    def DataType_String.unpack!(buffer)
      len = DataType_Integer.unpack!(buffer) ;
      str = buffer.slice!(0,len) ;
      return str ;
    end

    #--------------------------------------------------------------
    #++
    ## size of packed string data
    def DataType_String.actualSize(value)
      return (DataType_Integer.size +	# length part
              value.length) ;
    end

    #--------------------------------------------------------------
    #++
    ## string unpack
    def DataType_String.pack(value, withTypeTag = false)
      if(withTypeTag)
        return [DataType_UByte.pack(@id), self.pack(value,false)].join ;
      else
        return [DataType_Integer.pack(value.length), value].join ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## string list unpack
    def DataType_StringList.unpack!(buffer)
      n = DataType_Integer.unpack!(buffer) ;
      list = [] ;
      (0...n).each{|i|
        str = DataType_String.unpack!(buffer) ;
        list.push(str) ;
      }
      return list ;
    end

    #--------------------------------------------------------------
    #++
    ## size of packed string list 
    def DataType_StringList.actualSize(value)
      l = DataType_Integer.size ;
      value.each{|str|
        l += DataType_String.actualSize(str) ;
      }
      return l ;
    end

    #--------------------------------------------------------------
    #++
    ## string list unpack
    def DataType_StringList.pack(value, withTypeTag = false)
      packedList = [] ;
      packedList.push(DataType_UByte.pack(@id)) if(withTypeTag) ;
      packedList.push(DataType_Integer.pack(value.size)) ;
      value.each{|str|
        packedList.push(DataType_String.pack(str)) ;
      }
      return packedList.join ;
    end

    #--------------------------------------------------------------
    #++
    ## unpack by DataType id
    def DataTypeTable.unpack!(buffer)
      typeId = DataType_UByte.unpack!(buffer) ;
      dataType = self.getById(typeId) ;
      raise "unknown data type ID:" + typeId.to_s if(dataType.nil?) ;

      return dataType.unpack!(buffer) ;
    end

    #--============================================================
    #++
    ## Traffic Light Phase
    class TrafficLightPhase < Util::NamedIdEntry
    end # class TrafficLightPhase

    #--============================================================
    #++
    ## Table for TrafficLightPhase
    class TrafficLightPhaseTable < Util::NamedIdTable
      def entryClass
        TrafficLightPhase
      end
    end # class TrafficLightPhaseTable

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## Traci Traffic Light Phase Table definitions
    TrafficLightPhaseTable.add(:red, "TLPHASE_RED") ;
    TrafficLightPhaseTable.add(:yellow, "TLPHASE_YELLOW") ;
    TrafficLightPhaseTable.add(:green, "TLPHASE_GREEN") ;
    TrafficLightPhaseTable.add(:blinking, "TLPHASE_BLINKING") ;
    TrafficLightPhaseTable.add(:off, "TLPHASE_NOSIGNAL") ;

    #--============================================================
    #++
    ## DomainId of Variable
    class DomainId < Util::NamedIdEntry
    end # class DomainId

    #--============================================================
    #++
    ## Table for DomainId
    class DomainIdTable < Util::NamedIdTable
      def entryClass
        DomainId
      end
    end # class DomainIdTable

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## DomainId Entry
    DomainIdTable.add(:inductionLoop, "CMD_GET_INDUCTIONLOOP_VARIABLE") ;
    DomainIdTable.add(:arealDetector, "CMD_GET_AREAL_DETECTOR_VARIABLE") ;
    DomainIdTable.add(:multiEntryExitDetector, "CMD_GET_MULTI_ENTRY_EXIT_DETECTOR_VARIABLE") ;
    DomainIdTable.add(:tl, "CMD_GET_TL_VARIABLE") ;
    DomainIdTable.add(:lane, "CMD_GET_LANE_VARIABLE") ;
    DomainIdTable.add(:vehicle, "CMD_GET_VEHICLE_VARIABLE") ;
    DomainIdTable.add(:vehicleType, "CMD_GET_VEHICLETYPE_VARIABLE") ;
    DomainIdTable.add(:route, "CMD_GET_ROUTE_VARIABLE") ;
    DomainIdTable.add(:poi, "CMD_GET_POI_VARIABLE") ;
    DomainIdTable.add(:polygon, "CMD_GET_POLYGON_VARIABLE") ;
    DomainIdTable.add(:junction, "CMD_GET_JUNCTION_VARIABLE") ;
    DomainIdTable.add(:edge, "CMD_GET_EDGE_VARIABLE") ;
    DomainIdTable.add(:sim, "CMD_GET_SIM_VARIABLE") ;
    DomainIdTable.add(:gui, "CMD_GET_GUI_VARIABLE") ;

    ## Difference between CMD_GET_* and RESPONSE_GET_*
    DomainIdDiff_Get_Response = 0x10 ;
    ## Difference between CMD_GET_* and CMD_SET_*
    DomainIdDiff_Get_Set = 0x20 ;

    #--============================================================
    #++
    ## Variable Id
    class VariableId < Util::NamedIdEntry

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## data type of the variable
      attr :type, true ;

      #----------------------------------------------------
      #++
      ## initialization
      ## _name_:: name of data type. should be Symbol.
      ## _cname_:: name in Constant table. should be String.
      ## _type_:: data type
      def initialize(name, cname, type)
        super
        @type = type ;
      end
    end # class VariableId

    #--============================================================
    #++
    ## Table for Variable
    class VariableIdTable < Util::NamedIdTable
      def entryClass
        VariableId
      end
    end # class VariableIdTable

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## VariableID Entry Definitions (for Get Vehicle Variable)
    VariableIdTable.add(:idList, 	# 0x00 (for Get Vehicle Variable)
                        "ID_LIST", :stringList) ;
    VariableIdTable.add(:idCount, 	# 0x01 (for Get Vehicle Variable)
                        "ID_COUNT", :integer) ;
    VariableIdTable.add(:objectVariablesSubscription,	# 0x02 
                        "OBJECT_VARIABLES_SUBSCRIPTION", nil) ;
    VariableIdTable.add(:surroundingVariablesSubscription, 	#0x03
                        "SURROUNDING_VARIABLES_SUBSCRIPTION", nil) ;
    VariableIdTable.add(:lastStepVehicleNumber, 	# 0x10
                        "LAST_STEP_VEHICLE_NUMBER", :integer) ;
    VariableIdTable.add(:lastStepMeanSpeed, 	# 0x11
                        "LAST_STEP_MEAN_SPEED", :double) ;
    VariableIdTable.add(:lastStepVehicleIdList, 	# 0x12
                        "LAST_STEP_VEHICLE_ID_LIST", :stringList) ;
    VariableIdTable.add(:lastStepOccupancy, 	# 0x13
                        "LAST_STEP_OCCUPANCY", :double) ;
    VariableIdTable.add(:lastStepVehicleHaltingNumber, 	# 0x14
                        "LAST_STEP_VEHICLE_HALTING_NUMBER", :integer) ;
    VariableIdTable.add(:lastStepLength, 	# 0x15
                        "LAST_STEP_LENGTH", :double) ;
    VariableIdTable.add(:lastStepTimeSinceDetection, 	# 0x16
                        "LAST_STEP_TIME_SINCE_DETECTION", :double) ;
    VariableIdTable.add(:lastStepVehicleData, 	# 0x17
                        "LAST_STEP_VEHICLE_DATA", nil) ; ## complex
    VariableIdTable.add(:jamLengthVehicle, 	# 0x18
                        "JAM_LENGTH_VEHICLE", :integer) ;
    VariableIdTable.add(:jamLengthMeters, 	# 0x19
                        "JAM_LENGTH_METERS", :integer) ;
    VariableIdTable.add(:tlRedYellowGreenState, 	# 0x20
                        "TL_RED_YELLOW_GREEN_STATE", :string) ;
    VariableIdTable.add(:tlPhaseIndex, 	# 0x22
                        "TL_PHASE_INDEX", :integer) ;
    VariableIdTable.add(:tlProgram, 	# 0x23
                        "TL_PROGRAM", :string) ;
    VariableIdTable.add(:tlPhaseDuration, 	# 0x24
                        "TL_PHASE_DURATION", :integer) ;
    VariableIdTable.add(:tlControlledLanes, 	# 0x26
                        "TL_CONTROLLED_LANES", :stringList) ;
    VariableIdTable.add(:tlControlledLinks, 	# 0x27
                        "TL_CONTROLLED_LINKS", :integer) ;
    VariableIdTable.add(:tlCurrentPhase, 	# 0x28
                        "TL_CURRENT_PHASE", :integer) ;
    VariableIdTable.add(:tlCurrentProgram, 	# 0x29
                        "TL_CURRENT_PROGRAM", :string) ;
    VariableIdTable.add(:tlControlledJunctions, 	# 0x2a
                        "TL_CONTROLLED_JUNCTIONS", nil) ;
    VariableIdTable.add(:tlCompleteDefinitionRyg,	# 0x2b
                        "TL_COMPLETE_DEFINITION_RYG", nil) ; # compound 
    VariableIdTable.add(:tlCompleteProgramRyg, 	# 0x2c
                        "TL_COMPLETE_PROGRAM_RYG", nil) ; # compound
    VariableIdTable.add(:tlNextSwitch, 	# 0x2d
                        "TL_NEXT_SWITCH", :integer) ;
    VariableIdTable.add(:laneLinkNumber, 	# 0x30
                        "LANE_LINK_NUMBER", :ubyte) ;
    VariableIdTable.add(:laneEdgeId, 	# 0x31
                        "LANE_EDGE_ID", :string) ;
    VariableIdTable.add(:laneLinks,                         # 0x33
                        "LANE_LINKS", nil) ;                # compound
    VariableIdTable.add(:laneAllowed, 	# 0x34
                        "LANE_ALLOWED", :stringList) ;
    VariableIdTable.add(:laneDisallowed, 	# 0x35
                        "LANE_DISALLOWED", :stringList) ;
    VariableIdTable.add(:speed, 	# 0x40 (for Get Vehicle Variable)
                        "VAR_SPEED", :double) ;
    VariableIdTable.add(:maxSpeed, 	# 0x41 (:vmax for Get Vehicle Variable)
                        "VAR_MAXSPEED", :double) ;
    VariableIdTable.add(:position, 	# 0x42 (for Get Vehicle Variable)
                        "VAR_POSITION", :pos2D) ;
    VariableIdTable.add(:angle, 	# 0x43 (for Get Vehicle Variable)
                        "VAR_ANGLE", :double) ;
    VariableIdTable.add(:length, 	# 0x44 (for Get Vehicle Variable)
                        "VAR_LENGTH", :double) ;
    VariableIdTable.add(:color, 	# 0x45 (for Get Vehicle Variable)
                        "VAR_COLOR", :color) ;
    VariableIdTable.add(:accel, 	# 0x46 (for Get Vehicle Variable)
                        "VAR_ACCEL", :double) ;
    VariableIdTable.add(:decel, 	# 0x47 (for Get Vehicle Variable)
                        "VAR_DECEL", :double) ;
    VariableIdTable.add(:tau, 	# 0x48 (for Get Vehicle Variable)
                        "VAR_TAU", :double) ;
    VariableIdTable.add(:vehicleClass, 	# 0x49 (for Get Vehicle Variable)
                        "VAR_VEHICLECLASS", :string) ;
    VariableIdTable.add(:emissionClass, 	# 0x4a (for Get Vehicle Variable)
                        "VAR_EMISSIONCLASS", :string) ;
    VariableIdTable.add(:shapeClass, 	# 0x4b (for Get Vehicle Variable)
                        "VAR_SHAPECLASS", :string) ;
    VariableIdTable.add(:minGap, 	# 0x4c (for Get Vehicle Variable)
                        "VAR_MINGAP", :double) ;
    VariableIdTable.add(:width, 	# 0x4d (for Get Vehicle Variable)
                        "VAR_WIDTH", :double) ;
    VariableIdTable.add(:shape, 			# 0x4e
                        "VAR_SHAPE", nil) ;		# 2D-polygon
    VariableIdTable.add(:type, 	# 0x4f
                        "VAR_TYPE", :string) ;
    VariableIdTable.add(:roadId, 	# 0x50 (for Get Vehicle Variable)
                        "VAR_ROAD_ID", :string) ;
    VariableIdTable.add(:laneId, 	# 0x51 (for Get Vehicle Variable)
                        "VAR_LANE_ID", :string) ;
    VariableIdTable.add(:laneIndex, 	# 0x52 (for Get Vehicle Variable)
                        "VAR_LANE_INDEX", :integer) ;
    VariableIdTable.add(:routeId, 	# 0x53 (for Get Vehicle Variable)
                        "VAR_ROUTE_ID", :string) ;
    VariableIdTable.add(:edges, 	# 0x54 (for Get Vehicle Variable)
                        "VAR_EDGES", :stringList) ;
    VariableIdTable.add(:fill, 	# 0x55
                        "VAR_FILL", :ubyte) ;
    VariableIdTable.add(:lanePosition, 	# 0x56 (for Get Vehicle Variable)
                        "VAR_LANEPOSITION", :double) ;
    VariableIdTable.add(:route, 	# 0x57
                        "VAR_ROUTE", :stringList) ;
    VariableIdTable.add(:edgeTravelTime, 	# 0x58 (for Get Vehicle Variable)
                        "VAR_EDGE_TRAVELTIME", :arg4ChangeEdgeTravelTime2) ; 
				# compounded (sec. ChangeVehicleState)
    				# used also sec. ChangeEdgeState.
    VariableIdTable.add(:edgeEffort, 	# 0x59 (for Get Vehicle Variable)
                        "VAR_EDGE_EFFORT", :arg4ChangeEdgeErrort2) ; 
    				# compounded (sec. Change Vehicle State)
    				# used also sec. ChangeEdgeState.
    VariableIdTable.add(:currentTravelTime, 	# 0x5a
                        "VAR_CURRENT_TRAVELTIME", :double) ;
    VariableIdTable.add(:signals, 	# 0x5b (:signalStates for Get Vehicle Variable)
                        "VAR_SIGNALS", :integer) ; # bitwise. see TraCI/Vehicle Signalling
    VariableIdTable.add(:imperfection, 	# 0x5d (:sigma for Get Vehicle Variable)
                        "VAR_IMPERFECTION", :double) ; # = sigma
    VariableIdTable.add(:speedFactor, 	# 0x5e (for Get Vehicle Variable)
                        "VAR_SPEED_FACTOR", :double) ;
    VariableIdTable.add(:speedDeviation, 	# 0x5f (for Get Vehicle Variable)
                        "VAR_SPEED_DEVIATION", :double) ;
    VariableIdTable.add(:routeIndex, 	# 0x69 (for Get Vehicle Variable)
                        "VAR_ROUTE_INDEX", :integer) ;
    VariableIdTable.add(:speedWithoutTraci, 	# 0xb1
                        "VAR_SPEED_WITHOUT_TRACI", nil) ;
    VariableIdTable.add(:bestLanes, 	# 0xb2 (for Get Vehicle Variable)
                        "VAR_BEST_LANES", :complex) ; #??? 
                         # should be check in Vehicle Variable.  
    VariableIdTable.add(:moveToVtd, 	# 0xb4
                        "VAR_MOVE_TO_VTD", nil) ;
    VariableIdTable.add(:stopState, 	# 0xb5 (for Get Vehicle Variable)
                        "VAR_STOPSTATE", :ubyte) ; # bitwise. See StopFlagBitTable
    VariableIdTable.add(:allowedSpeed, 	# 0xb7
                        "VAR_ALLOWED_SPEED", nil) ;
    VariableIdTable.add(:co2Emission, 	# 0x60 (for Get Vehicle Variable)
                        "VAR_CO2EMISSION", :double) ;
    VariableIdTable.add(:coEission, 	# 0x61 (for Get Vehicle Variable)
                        "VAR_COEMISSION", :double) ;
    VariableIdTable.add(:hcEmission, 	# 0x62 (for Get Vehicle Variable)
                        "VAR_HCEMISSION", :double) ;
    VariableIdTable.add(:pmxEmission, 	# 0x63 (for Get Vehicle Variable)
                        "VAR_PMXEMISSION", :double) ;
    VariableIdTable.add(:noxEmission, 	# 0x64 (for Get Vehicle Variable)
                        "VAR_NOXEMISSION", :double) ;
    VariableIdTable.add(:fuelConsumption, 	# 0x65 (for Get Vehicle Variable)
                        "VAR_FUELCONSUMPTION", :double) ;
    VariableIdTable.add(:noiseEmission, 	# 0x66 (for Get Vehicle Variable)
                        "VAR_NOISEEMISSION", :double) ;
    VariableIdTable.add(:personNumber, 	# 0x67
                        "VAR_PERSON_NUMBER", nil) ;
    VariableIdTable.addExtra(:busStopWaiting, 	# 0x67
                             "VAR_BUS_STOP_WAITING", nil) ;
    VariableIdTable.add(:leader, 	# 0x68 (for Get Vehicle Variable)
                        "VAR_LEADER", nil) ;
    VariableIdTable.add(:waitingTime, 	# 0x7a. used in get in vehicle and lane
                             "VAR_WAITING_TIME", nil) ;
				#conflict with simulation's
				# VAR_ARRIVED_VEHICLES_IDS

    ##--::::::::::::::::::::::::::::::
    # for Simulation Variable (0xab)
    VariableIdTable.add(:timeStep, 	# 0x70
                        "VAR_TIME_STEP", :integer) ;
    VariableIdTable.add(:loadedVehiclesNumber, 	# 0x71
                        "VAR_LOADED_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:loadedVehiclesIds, 	# 0x72
                        "VAR_LOADED_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:departedVehiclesNumber, 	# 0x73
                        "VAR_DEPARTED_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:departedVehiclesIds, 	# 0x74
                        "VAR_DEPARTED_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:teleportStartingVehiclesNumber, 	# 0x75
                        "VAR_TELEPORT_STARTING_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:teleportStartingVehiclesIds, 	# 0x76
                        "VAR_TELEPORT_STARTING_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:teleportEndingVehiclesNumber, 	# 0x77
                        "VAR_TELEPORT_ENDING_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:teleportEndingVehiclesIds, 	# 0x78
                        "VAR_TELEPORT_ENDING_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:arrivedVehiclesNumber, 	# 0x79
                        "VAR_ARRIVED_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.addExtra(:arrivedVehiclesIds, 	# 0x7a
                             "VAR_ARRIVED_VEHICLES_IDS", :stringList) ;
    				# ID conflicts with :waitingTime
    VariableIdTable.add(:deltaT, 	# 0x7b
                        "VAR_DELTA_T", nil) ;
    VariableIdTable.add(:netBoundingBox, 	# 0x7c
                        "VAR_NET_BOUNDING_BOX", :boundaryBox) ;
    VariableIdTable.add(:minExpectedVehicles, 	# 0x7d
                        "VAR_MIN_EXPECTED_VEHICLES", :integer) ;
    VariableIdTable.addExtra(:stopStartingVehiclesNumber, 	# 0x68
                             "VAR_STOP_STARTING_VEHICLES_NUMBER", :integer) ;
    				# ID conflict with :leader
    VariableIdTable.add(:stopStartingVehiclesIds, 	# 0x69
                        "VAR_STOP_STARTING_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:stopEndingVehiclesNumber, 	# 0x6a
                        "VAR_STOP_ENDING_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:stopEndingVehiclesIds, 	# 0x6b
                        "VAR_STOP_ENDING_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:parkingStartingVehiclesNumber, 	# 0x6c
                        "VAR_PARKING_STARTING_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:parkingStartingVehiclesIds, 	# 0x6d
                        "VAR_PARKING_STARTING_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:parkingEndingVehiclesNumber, 	# 0x6e
                        "VAR_PARKING_ENDING_VEHICLES_NUMBER", :integer) ;
    VariableIdTable.add(:parkingEndingVehiclesIds, 	# 0x6f
                        "VAR_PARKING_ENDING_VEHICLES_IDS", :stringList) ;
    VariableIdTable.add(:cmdClearPendingVehicles, 	# 0x94
                        "CMD_CLEAR_PENDING_VEHICLES", nil) ;
    #
    #VariableIdTable.add(:add, 		# 0x80
    #                    "ADD", nil) ;	# complex (sec. Change Vehicle State)
    # 					# stringList (sec. ChangeRouteState)
    #					# POD-def (sec. Change PoI State)
    #					# polygon-def (sec. Change Plygon State)
    #VariableIdTable.add(:remove, 	# 0x81
    #                    "REMOVE", nil) ; # complex (sec. Change Vehicle State)
    #                 			 # integer (sec. Change PoI State)
    #                 			 # polygon-def (sec. Change Plygon State)
    VariableIdTable.add(:positionConversion, 
                        "POSITION_CONVERSION", nil) ;	# 0x82
    VariableIdTable.add(:distanceRequest, 	# 0x83
                        "DISTANCE_REQUEST", nil) ;
    VariableIdTable.add(:distance, 	# 0x84
                        "VAR_DISTANCE", nil) ;
    VariableIdTable.add(:routeValid, 	# 0x92
                        "VAR_ROUTE_VALID", nil) ;
    VariableIdTable.add(:viewZoom, 	# 0xa0
                        "VAR_VIEW_ZOOM", :double) ;
    VariableIdTable.add(:viewOffset, 	# 0xa1
                        "VAR_VIEW_OFFSET", :pos2D) ;
    VariableIdTable.add(:viewSchema, 	# 0xa2
                        "VAR_VIEW_SCHEMA", :string) ;
    VariableIdTable.add(:viewBoundary, 	# 0xa3
                        "VAR_VIEW_BOUNDARY", :polygon) ; ## ??? bbox?
    VariableIdTable.add(:screenShot, 	# 0xa5
                        "VAR_SCREENSHOT", nil) ;
    VariableIdTable.add(:trackVehicle, 	# 0xa6
                        "VAR_TRACK_VEHICLE", nil) ;

    ##--::::::::::::::::::::::::::::::
    ## for SetVariable [Vehicle, DOM=0xc4]
    VariableIdTable.addExtra(:stop0, 	# 0x12,
                             "CMD_STOP", :arg4Stop0) ;
    VariableIdTable.addExtra(:stop1, 	# 0x12,  with :stopFlag
                             "CMD_STOP", :arg4Stop1) ;
    VariableIdTable.addExtra(:stop2, 	# 0x12,  with :startPosition
                             "CMD_STOP", :arg4Stop2) ;
    VariableIdTable.addExtra(:stop3, 	# 0x12,  with :until
                             "CMD_STOP", :arg4Stop3) ;
    VariableIdTable.addExtra(:changeLane, # 0x13
                             "CMD_CHANGELANE", :arg4ChangeLane) ;
    VariableIdTable.addExtra(:slowDown, # 0x14
                             "CMD_SLOWDOWN", :arg4SlowDown) ;
    VariableIdTable.addExtra(:resume, # 0x19
                             "CMD_RESUME", :arg4Resume) ;
    VariableIdTable.add(:changeTarget, # 0x31 -> same as :laneEdgeId
                        "LANE_EDGE_ID", :string) ;
    ### VariableIdTable.add(:speed, # 0x40 -> already defined as :speed
    ###                    "VAR_SPEED", :double) ;
    ### VariableIdTable.add(:color, # 0x45 -> already defined as :color
    ###                    "VAR_COLOR", :color) ;
    ### VariableIdTable.add(:changeRouteById,  # 0x53 -> same as :routeId
    ###                    "VAR_ROUTE_ID", :string) ;
    ### VariableIdTable.add(:changeRoute,  # 0x57 -> same as :route
    ###                    "VAR_ROUTE", :stringList) ;
    VariableIdTable.addExtra(:changeEdgeTravelTime4, # 0x58, 
                        "VAR_EDGE_TRAVELTIME", :arg4ChangeEdgeTravelTime4) ; 
    VariableIdTable.addExtra(:changeEdgeTravelTime2, # 0x58, 
                             "VAR_EDGE_TRAVELTIME", :arg4ChangeEdgeTravelTime2) ; 
    VariableIdTable.addExtra(:changeEdgeTravelTime1, # 0x58, 
                             "VAR_EDGE_TRAVELTIME", :arg4ChangeEdgeTravelTime1) ; 
    VariableIdTable.addExtra(:changeEdgeEffort4, # 0x59
                        "VAR_EDGE_EFFORT", :arg4ChangeEdgeEffort4) ; 
    VariableIdTable.addExtra(:changeEdgeEffort2, # 0x59
                             "VAR_EDGE_EFFORT", :arg4ChangeEdgeEffort2) ; 
    VariableIdTable.addExtra(:changeEdgeEffort1, # 0x59
                             "VAR_EDGE_EFFORT", :arg4ChangeEdgeEffort1) ; 
    ### VariableIdTable.add(:signalStates, # 0x5b -> already defined as :signales
    ###                    "VAR_SIGNALS", :integer) ; # bitwise. see TraCI/Vehicle Signalling
    VariableIdTable.add(:moveTo, 	# 0x5c
                        "VAR_MOVE_TO", :arg4MoveTo) ; 
    VariableIdTable.add(:rerouteByTravelTime, # 0x90
                        "CMD_REROUTE_TRAVELTIME", :compoundNil) ;
    VariableIdTable.add(:rerouteEffort, 	# 0x91
                        "CMD_REROUTE_EFFORT", :compoundNil) ;
    VariableIdTable.add(:speedMode, 	# 0xb3
                        "VAR_SPEEDSETMODE", :integer) ; # bitwise
    VariableIdTable.add(:laneChangeMode, # 0xb6
                        "VAR_LANECHANGE_MODE", :integer) ; # bitwise
    VariableIdTable.add(:addVehicle, # 0x80.  "ADD" is used in various domain.
                        "ADD", :arg4Add) ;
    VariableIdTable.add(:addFull, 	# 0x85
                        "ADD_FULL", :arg4AddFull) ;
    VariableIdTable.add(:removeVehicle,	# 0x81. "REMOVE" is used in various domain.
                        "REMOVE", :byte) ; # bitwise
#                        "REMOVE", :ubyte) ; # bitwise
    ### VariableIdTable.add(:length, 	# 0x44 -> already defined
    ###                    "VAR_LENGTH", :double) ;
    ### VariableIdTable.add(:maxSpeed, 	# 0x41 -> already defined
    ###                    "VAR_MAXSPEED", :double) ;
    ### VariableIdTable.add(:vehicleClass, 	# 0x49 -> already defined
    ###                    "VAR_VEHICLECLASS", :string) ;
    ### VariableIdTable.add(:speedFactor, 	# 0x5e -> already defined
    ###                    "VAR_SPEED_FACTOR", :double) ;
    ### VariableIdTable.add(:emissionClass, 	# 0x4a -> already defined
    ###                    "VAR_EMISSIONCLASS", :string) ;
    ### VariableIdTable.add(:width, 	# 0x4d -> already defined
    ###                    "VAR_WIDTH", :double) ;
    ### VariableIdTable.add(:minGap, 	# 0x4c -> already defined
    ###                    "VAR_MINGAP", :double) ;
    ### VariableIdTable.add(:shapeClass, 	# 0x4b -> already defined
    ###                    "VAR_SHAPECLASS", :string) ;
    ### VariableIdTable.add(:accel, 	# 0x46 -> already defined
    ###                    "VAR_ACCEL", :double) ;
    ### VariableIdTable.add(:decel, 	# 0x47 -> already defined
    ###                    "VAR_DECEL", :double) ;
    ### VariableIdTable.add(:imperfection, 	# 0x5d -> already defined
    ###                    "VAR_IMPERFECTION", :double) ; # = sigma
    ### VariableIdTable.add(:tau, 	# 0x48 -> already defined
    ###                    "VAR_TAU", :double) ;

    ##--::::::::::::::::::::::::::::::
    ## for SetVariable [Change Route, DOM=0xc6]
    VariableIdTable.add(:addRoute, # 0x80.  "ADD" is used in various domain.
                        "ADD", :stringList) ;

    ##--::::::::::::::::::::::::::::::
    ## for SetVariable [Change PoI, DOM=0xc7]
    VariableIdTable.add(:addPoi, # 0x80.  "ADD" is used in various domain.
                        "ADD", :arg4AddPoi) ;
    VariableIdTable.add(:removePoi, # 0x80.  "ADD" is used in various domain.
                        "REMOVE", :integer) ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    StopFlagBitTable = { :parking => 		0b00000001,
                         :triggered => 		0b00000010,
                         :containerTriggered =>	0b00000100,
                         :busStop => 		0b00001000,
                         :containerStop => 	0b00010000,
                         :chargingStation => 	0b00100000,
                         :parkingArea => 	0b01000000,
                       } ;
    #--------------------------------------------------------------
    #++
    ## form bitwised StopFlag.
    ## _flagList_ :: an Array of flags that consists of flag symbols
    ##               in StopFlagBitTable.
    ## *return* :: bitwised flag.
    def self.formStopFlagBits(flagList)
      flagBits = 0b00000000 ;
      flagList.each{|flag|
        bit = StopFlagBitTable[flag] ;
        raise "unknown stop flag :#{flag}" if(bit.nil?) ;
        flagBits |= bit ;
      }
      return flagBits ;
    end

    #--------------------------------------------------------------
    #++
    ## form an Array of flags from bitwised StopFlag.
    ## _flagBits_ :: bitwised flag.
    ## *return* :: an Array of flags.
    def self.formStopFlagList(flagBits)
      flagList = [] ;
      StopFlagBitTable.each{|flag, bit|
        flagList.push(flag) if((flagBits & bit) > 0) ;
      }
      return flagList ;
    end

    #--============================================================
    #++
    ## Result Code Description
    class ResultCodeDesc < Util::NamedIdEntry
      #--------------------------------
      #++
      ## check the result code is fine.
      def isOk?()
        return @name == :ok ;
      end
      
    end # class ResultCodeDesc

    #--============================================================
    #++
    ## Table for TrafficLightPhase
    class ResultCodeDescTable < Util::NamedIdTable
      def entryClass
        ResultCodeDesc
      end
    end # class ResultCodeDescTable

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## Traci Result Code Description definition
    ResultCodeDescTable.add(:ok, "RTYPE_OK") ;
    ResultCodeDescTable.add(:notImplemented, "RTYPE_NOTIMPLEMENTED") ;
    ResultCodeDescTable.add(:error, "RTYPE_ERR") ;

  end # module Traci

end # module Sumo

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_TraciClient < Test::Unit::TestCase
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
    ## show types
    def test_a
      pp Sumo::Traci::DataTypeTable.instance.tableByName ;
      pp Sumo::Traci::DataTypeTable.instance.tableById ;
    end

  end # class TC_TraciClient
end # if($0 == __FILE__)
