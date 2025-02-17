# frozen_string_literal: true

require 'openstudio'
require 'lib/baseline_model'

m = BaselineModel.new

# make a 2 story, 100m X 50m, 10 zone core/perimeter building
m.add_geometry({ 'length' => 100,
                 'width' => 50,
                 'num_floors' => 2,
                 'floor_to_floor_height' => 4,
                 'plenum_height' => 1,
                 'perimeter_zone_depth' => 3 })

# add windows at a 40% window-to-wall ratio
m.add_windows({ 'wwr' => 0.4,
                'offset' => 1,
                'application_type' => 'Above Floor' })

# add thermostats
m.add_thermostats({ 'heating_setpoint' => 24,
                    'cooling_setpoint' => 28 })

# assign constructions from a local library to the walls/windows/etc. in the model
m.set_constructions

# set whole building space type; simplified 90.1-2004 Large Office Whole Building
m.set_space_type

# add design days to the model (Chicago)
m.add_design_days

# add ASHRAE System type 07, VAV w/ Reheat
m.add_hvac({ 'ashrae_sys_num' => '07' })

# In order to produce more consistent results between different runs,
# we sort the zones by names
zones = m.getThermalZones.sort_by { |z| z.name.to_s }

# CoilCoolingDXTwoStageWithHumidityControlMode
zone = zones[0]
zone.airLoopHVAC.get.removeBranchForZone(zone)
airloop = OpenStudio::Model.addSystemType3(m).to_AirLoopHVAC.get
airloop.setName('AirLoopHVAC CoilCoolingDXTwoStageWithHumidityControlMode')
airloop.addBranchForZone(zone)
coil = airloop.supplyComponents(OpenStudio::Model::CoilCoolingDXSingleSpeed.iddObjectType).first.to_StraightComponent.get
node = coil.outletModelObject.get.to_Node.get
new_coil = OpenStudio::Model::CoilCoolingDXTwoStageWithHumidityControlMode.new(m)
new_coil.addToNode(node)
coil.remove

# CoilSystemCoolingDXHeatExchangerAssisted
zone = zones[1]
zone.airLoopHVAC.get.removeBranchForZone(zone)
airloop = OpenStudio::Model::AirLoopHVAC.new(m)
airloop.setName('AirLoopHVAC Unitary with CoilSystemCoolingDXHX')
alwaysOn = m.alwaysOnDiscreteSchedule
# Starting with E 9.0.0, Uncontrolled is deprecated and replaced with
# ConstantVolume:NoReheat
if Gem::Version.new(OpenStudio.openStudioVersion) >= Gem::Version.new('2.7.0')
  terminal = OpenStudio::Model::AirTerminalSingleDuctConstantVolumeNoReheat.new(m, alwaysOn)
else
  terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(m, alwaysOn)
end
airloop.addBranchForZone(zone, terminal)
unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(m)
unitary.setFanPlacement('BlowThrough')
fan = OpenStudio::Model::FanOnOff.new(m)
unitary.setSupplyFan(fan)
heating_coil = OpenStudio::Model::CoilHeatingElectric.new(m)
unitary.setHeatingCoil(heating_coil)
cooling_coil = OpenStudio::Model::CoilSystemCoolingDXHeatExchangerAssisted.new(m)
unitary.setCoolingCoil(cooling_coil)
unitary.addToNode(airloop.supplyOutletNode)
unitary.setControllingZoneorThermostatLocation(zone)

# CoilCoolingDXVariableSpeed
zone = zones[2]
zone.airLoopHVAC.get.removeBranchForZone(zone)
airloop = OpenStudio::Model.addSystemType7(m).to_AirLoopHVAC.get
airloop.setName('AirLoopHVAC Coil DX VariableSpeeds')
airloop.addBranchForZone(zone)
coil = airloop.supplyComponents(OpenStudio::Model::CoilCoolingWater.iddObjectType).first.to_CoilCoolingWater.get
newcoil = OpenStudio::Model::CoilCoolingDXVariableSpeed.new(m)
coildata = OpenStudio::Model::CoilCoolingDXVariableSpeedSpeedData.new(m)
newcoil.addSpeed(coildata)
newcoil.addToNode(coil.airOutletModelObject.get.to_Node.get)
coil.remove

node = newcoil.outletModelObject.get.to_Node.get

# CoilHeatingDXVariableSpeed
newcoil = OpenStudio::Model::CoilHeatingDXVariableSpeed.new(m)
coildata = OpenStudio::Model::CoilHeatingDXVariableSpeedSpeedData.new(m)
newcoil.addSpeed(coildata)
newcoil.addToNode(node)

# save the OpenStudio model (.osm)
m.save_openstudio_osm({ 'osm_save_directory' => Dir.pwd,
                        'osm_name' => 'in.osm' })
