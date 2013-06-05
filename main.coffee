fs = require 'fs'
ccSvc = require 'ccxmleventemitter'
redis = require 'redis'

config = require './config'  #json file

redisConfig = config["redisConfig"]

unless redisConfig?
  console.log "no redisConfig, exiting..."
  return

console.log redisConfig


db = redis.createClient redisConfig.port, redisConfig.host, redisConfig
db.select redisConfig.db

meterReadings = config["meterReadings"]
console.log meterReadings


#CC128.message.host.device = CC128.base.1.1 or CC128.sensor.1.1
mapping = config["mapping"]

unless mapping?
  mapping = config["mapping"] = {host:1,device:1}
  
   
console.log mapping


#create a new instance of the BaseStation on serial port /dev/ttyUSB0
#we will use the OS time for events instead of the base stations time
#we will report base messages every 30 secs (these contain temp etc)
#we will initialise sensor '9' with a reading of 1100.000 (this could represent the reading on a meter dial)

options = 
          useOSTime      : true 
          debug          : false 
          emitBaseEvery  : 30
          reading        : meterReadings 
          spikeThreshold : 60
          

#see also config["reportOnZeroWatts"]:true if you want to generate redis messages on 0 watt sensor events.


envir = new ccSvc.CurrentCost128XMLBaseStation '/dev/ttyUSB0', options


if true

  envir.on 'base', (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.base.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo)
    console.log "This base station is using #{eventinfo.src} firmware and has been running for #{eventinfo.dsb} days. The temperature is currently #{eventinfo.temp}"

  envir.on 'sensor' , (eventinfo) ->
#    console.log eventinfo
    if (eventinfo.watts != 0) or (config["reportOnZeroWatts"] == true )
      db.publish "cc128.sensor.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo)      
      console.log "Whole House consumption reported as  #{eventinfo.watts} watts" if eventinfo.sensor == '0'
      console.log "Sensor #{eventinfo.sensor} reported as  #{eventinfo.watts} watts" if eventinfo.sensor != '0'


  envir.on 'impulse', (eventinfo) ->
#    console.log String.fromCharCode 7
#    console.log eventinfo
    db.publish "cc128.impulse-count.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "There have been #{eventinfo.value} impulses on sensor #{eventinfo.sensor} since the sensor was powered on"


  envir.on 'impulse-reading' , (eventinfo) ->
#    console.log eventinfo
    meterReadings[eventinfo.sensor] = eventinfo.reading
    db.publish "cc128.impulse-reading.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "Sensor #{eventinfo.sensor} reports a reading of #{eventinfo.reading}"



  envir.on 'impulse-delta' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-delta.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "There have been #{eventinfo.delta} impulses on sensor #{eventinfo.sensor} since the last reported event"



  envir.on 'impulse-avg' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-avg.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "Sensor #{eventinfo.sensor} reports an average consumption of #{eventinfo.avg} units since last reported event"

  envir.on 'impulse-spike' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-spike.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "Sensor #{eventinfo.sensor} reports a spike of #{eventinfo.spike} units since last reported event"

  envir.on 'impulse-correction' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-correction.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "Sensor #{eventinfo.sensor} reports a spike correction of #{eventinfo.newReading} units"

 envir.on 'impulse-warning' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-warning.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "Sensor #{eventinfo.sensor} reports a spike warning. Reading reset to #{eventinfo.newReading} units"



    
process.on 'SIGINT', () ->
  console.log  "\ngracefully shutting down from  SIGINT (Crtl-C)" 
  #save out config for next invocation incase we want reading data?
  console.log JSON.stringify config
  config["meterReadings"] = meterReadings
  fs.writeFileSync './config.json', JSON.stringify(config)

  
  envir.close()
  envir = null
  db.quit


  console.log "--EXIT--"
  process.exit 0






