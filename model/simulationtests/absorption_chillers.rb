# frozen_string_literal: true

require 'openstudio'
require 'lib/baseline_model'

model = BaselineModel.new

# make a 2 story, 100m X 50m, 10 zone core/perimeter building
model.add_geometry({ 'length' => 100,
                     'width' => 50,
                     'num_floors' => 2,
                     'floor_to_floor_height' => 4,
                     'plenum_height' => 1,
                     'perimeter_zone_depth' => 3 })

# add windows at a 40% window-to-wall ratio
model.add_windows({ 'wwr' => 0.4,
                    'offset' => 1,
                    'application_type' => 'Above Floor' })

# add ASHRAE System type 07, VAV w/ Reheat
model.add_hvac({ 'ashrae_sys_num' => '07' })

# In order to produce more consistent results between different runs,
# We ensure we do get the same object each time
cts = model.getCoolingTowerSingleSpeeds.sort_by { |c| c.name.to_s }
chillers = model.getChillerElectricEIRs.sort_by { |c| c.name.to_s }

condenser_plant = cts.first.plantLoop.get
chilled_plant = chillers.first.plantLoop.get

chiller = OpenStudio::Model::ChillerAbsorptionIndirect.new(model)
chilled_plant.addSupplyBranchForComponent(chiller)
condenser_plant.addDemandBranchForComponent(chiller)

chiller = OpenStudio::Model::ChillerAbsorption.new(model)
chilled_plant.addSupplyBranchForComponent(chiller)
condenser_plant.addDemandBranchForComponent(chiller)

# add thermostats
model.add_thermostats({ 'heating_setpoint' => 24,
                        'cooling_setpoint' => 28 })

# assign constructions from a local library to the walls/windows/etc. in the model
model.set_constructions

# set whole building space type; simplified 90.1-2004 Large Office Whole Building
model.set_space_type

# add design days to the model (Chicago)
model.add_design_days

# save the OpenStudio model (.osm)
model.save_openstudio_osm({ 'osm_save_directory' => Dir.pwd,
                            'osm_name' => 'in.osm' })
