# frozen_string_literal: true

require 'openstudio'
require 'lib/baseline_model'

model = BaselineModel.new

# make a 1 story, 100m X 50m, 1 zone core/perimeter building
model.add_geometry({ 'length' => 100,
                     'width' => 50,
                     'num_floors' => 1,
                     'floor_to_floor_height' => 4,
                     'plenum_height' => 1,
                     'perimeter_zone_depth' => 0 })

# add windows at a 40% window-to-wall ratio
model.add_windows({ 'wwr' => 0.4,
                    'offset' => 1,
                    'application_type' => 'Above Floor' })

# add thermostats
model.add_thermostats({ 'heating_setpoint' => 24,
                        'cooling_setpoint' => 28 })

# assign constructions from a local library to the walls/windows/etc. in the model
model.set_constructions

# set whole building space type; simplified 90.1-2004 Large Office Whole Building
model.set_space_type

# add design days to the model (Chicago)
model.add_design_days

# In order to produce more consistent results between different runs,
# we sort the zones by names (only one here anyways...)
zones = model.getThermalZones.sort_by { |z| z.name.to_s }

# Use Ideal Air Loads
zones.each { |z| z.setUseIdealAirLoads(true) }

material = OpenStudio::Model::StandardOpaqueMaterial.new(model)
material.setThickness(0.2032)
material.setConductivity(1.3114056)
material.setDensity(2242.8)
material.setSpecificHeat(837.4)

# Set a fractional continuous schedule, here we'll say the insulation is
# completely in place during the night (21 to 8), off during the day
scheduleRuleset = OpenStudio::Model::ScheduleRuleset.new(model)
night_schedule = scheduleRuleset.defaultDaySchedule
night_schedule.addValue(OpenStudio::Time.new(0, 8, 0, 0), 1.0)
night_schedule.addValue(OpenStudio::Time.new(0, 21, 0, 0), 0.0)
night_schedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)

# To ensure repeatability, we sort the surfaces by their name,
# and we keep only outside walls
surfaces = model.getSurfaces.select { |s| s.outsideBoundaryCondition == 'Outdoors' && s.surfaceType == 'Wall' }.sort_by { |s| s.name.to_s }
# set surface control movable insulation
surfaces.each do |surface|
  movableInsulation = OpenStudio::Model::SurfaceControlMovableInsulation.new(surface, material)
  movableInsulation.setInsulationType('Inside')
  movableInsulation.setSchedule(scheduleRuleset)
end

# save the OpenStudio model (.osm)
model.save_openstudio_osm({ 'osm_save_directory' => Dir.pwd,
                            'osm_name' => 'in.osm' })
