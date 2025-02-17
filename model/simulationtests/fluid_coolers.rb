# frozen_string_literal: true

require 'openstudio'
require 'lib/baseline_model'

model = BaselineModel.new

# make a 2 story, 100m X 50m, 10 zone core/perimeter building
model.add_geometry({ 'length' => 100,
                     'width' => 50,
                     'num_floors' => 1,
                     'floor_to_floor_height' => 4,
                     'plenum_height' => 1,
                     'perimeter_zone_depth' => 3 })

# add windows at a 40% window-to-wall ratio
model.add_windows({ 'wwr' => 0.4,
                    'offset' => 1,
                    'application_type' => 'Above Floor' })

# add ASHRAE System type 07, VAV w/ Reheat
model.add_hvac({ 'ashrae_sys_num' => '07' })

tower = model.getCoolingTowerSingleSpeeds.first
plant = tower.plantLoop.get

single_speed_evap_cooler = OpenStudio::Model::EvaporativeFluidCoolerSingleSpeed.new(model)
plant.addSupplyBranchForComponent(single_speed_evap_cooler)

single_speed_cooler = OpenStudio::Model::FluidCoolerSingleSpeed.new(model)
plant.addSupplyBranchForComponent(single_speed_cooler)

two_speed_cooler = OpenStudio::Model::FluidCoolerTwoSpeed.new(model)
plant.addSupplyBranchForComponent(two_speed_cooler)

two_speed_evap_cooler = OpenStudio::Model::EvaporativeFluidCoolerTwoSpeed.new(model)
plant.addSupplyBranchForComponent(two_speed_evap_cooler)

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
