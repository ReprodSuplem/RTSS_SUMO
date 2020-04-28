## -*- mode: Makefile -*-
## 
## = Sumo Utility
## Author:: Anonymous3
## Version:: 0.0 2018/01/21 Anonymous3
##
## === History
## * [2018/04/28]: Create This File.


RDOC_FILES = Doc_SumoUtil_Jp.rb \
		Savs/runSavSimRandom Savs/runSavSimMixture \
		Savs/analyzeDemandLog\
		Savs/SavAllocator.rb\
		Savs/SavAllocatorRandom.rb Savs/SavAllocatorSeqOpt.rb\
		Savs/SavBase.rb\
		Savs/SavDemand.rb\
		Savs/SavDemandFactory.rb\
		Savs/SavDemandFactoryRandom.rb\
		Savs/SavDemandFactoryMixture.rb\
		Savs/SavDemandFactoryUserGroup.rb\
		Savs/SavDemandFactoryDirected.rb\
		Savs/Vehicle.rb Savs/SavReporter.rb\
		Savs/SavUtil.rb Savs/SavTrip.rb Savs/SavViaPoint.rb\
		Traci/convSumoMapXml2Json\
		Traci/SumoManager.rb\
		Traci/SumoMap.rb\
		Traci/SumoMapEdge.rb Traci/SumoMapLane.rb\
		Traci/SumoMapJunction.rb Traci/SumoMapCoordSystem.rb\
		Traci/TraciPoi.rb Traci/TraciPoiManager.rb\
		Traci/TraciUtil.rb\
		Traci/TraciVehicleManager.rb\
		Traci/TraciVehicle.rb Traci/TraciVehicleLocation.rb\
		Tools/filterSavsTagInOsm

top : rdoc

rdoc :
	rdoc --hyperlink-all --force-update --line-numbers --diagram $(RDOC_FILES)
#	rdoc --force-update --one-file --line-numbers --diagram $(RDOC_FILES)
