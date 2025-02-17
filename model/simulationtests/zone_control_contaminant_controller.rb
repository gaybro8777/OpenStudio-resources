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

# add ASHRAE System type 03, PSZ-AC
model.add_hvac({ 'ashrae_sys_num' => '03' })

# add thermostats
model.add_thermostats({ 'heating_setpoint' => 24,
                        'cooling_setpoint' => 28 })

# add ZoneControlContaminantController
oa_cO2_schedule = OpenStudio::Model::ScheduleRuleset.new(model)
oa_cO2_schedule.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 400.0)

zoneAirContaminantBalance = model.getZoneAirContaminantBalance
zoneAirContaminantBalance.setCarbonDioxideConcentration(true)
zoneAirContaminantBalance.setOutdoorCarbonDioxideSchedule(oa_cO2_schedule)

co2_schedule = OpenStudio::Model::ScheduleRuleset.new(model)
co2_schedule.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 900.0)

# In order to produce more consistent results between different runs,
# we sort the zones by names (doesn't matter here, just in case)
zones = model.getThermalZones.sort_by { |z| z.name.to_s }
zones.each do |zone|
  controller = OpenStudio::Model::ZoneControlContaminantController.new(model)
  controller.setCarbonDioxideControlAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
  controller.setCarbonDioxideSetpointSchedule(co2_schedule)
  zone.setZoneControlContaminantController(controller)
end

air_systems = model.getAirLoopHVACs
air_systems.each do |air_system|
  controller = air_system.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir.controllerMechanicalVentilation
  controller.setSystemOutdoorAirMethod('ProportionalControlBasedonOccupancySchedule')
end

# assign constructions from a local library to the walls/windows/etc. in the model
model.set_constructions

# set whole building space type; simplified 90.1-2004 Large Office Whole Building
model.set_space_type

# add design days to the model (Chicago)
model.add_design_days

# save the OpenStudio model (.osm)
model.save_openstudio_osm({ 'osm_save_directory' => Dir.pwd,
                            'osm_name' => 'in.osm' })
