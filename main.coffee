fs = require 'fs'
ccSvc = require 'ccxmleventemitter'
redis = require 'redis'
logfile = "log.txt"
readlog = "reading.log"

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
          debug          : true 
          emitBaseEvery  : 30
          reading        : meterReadings 
          spikeThreshold : 60
          

#see also config["reportOnZeroWatts"]:true if you want to generate redis messages on 0 watt sensor events.


envir = new ccSvc.CurrentCost128XMLBaseStation '/dev/serusb/ccbase', options


console.log "envir version #{envir.version()}"

lastimp = 0

if true

  envir.on 'base', (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.base.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo)
    console.log "This base station is using #{eventinfo.src} firmware and has been running for #{eventinfo.dsb} days. The temperature is currently #{eventinfo.temp}"

  envir.on 'sensor' , (eventinfo) ->
#    console.log eventinfo
    if (eventinfo.watts != 0) or (config["reportOnZeroWatts"] == true )
      db.publish "cc128.sensor.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo)      
      console.log "Whole House consumption reported as  #{eventinfo.watts} watts for channel #{eventinfo.channel}" if eventinfo.sensor == '0'
      console.log "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reported as  #{eventinfo.watts} watts" if eventinfo.sensor != '0'


  envir.on 'impulse', (eventinfo) ->
#    console.log String.fromCharCode 7
#    console.log eventinfo
    db.publish "cc128.impulse-count.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "There have been #{eventinfo.value} impulses on sensor #{eventinfo.sensor}, channel #{eventinfo.channel} since the sensor was powered on"

    lastimp = eventinfo.value


  envir.on 'impulse-reading' , (eventinfo) ->
#    console.log eventinfo
    meterReadings[eventinfo.sensor] = eventinfo.reading
    db.publish "cc128.impulse-reading.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reports a reading of #{eventinfo.reading}"

    config["meterReadings"] = meterReadings
    fs.writeFileSync './config.json', JSON.stringify(config)

    #1
    fs.appendFileSync readlog, "\r\n" + eventinfo.reading


  envir.on 'impulse-delta' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-delta.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    console.log "There have been #{eventinfo.delta} impulses on sensor #{eventinfo.sensor}, channel #{eventinfo.channel} since the last reported event"

    #2
    fs.appendFileSync readlog, " " + eventinfo.delta




  envir.on 'impulse-avg' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-avg.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    data = "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reports an average consumption of #{eventinfo.avg} units since last reported event"
    console.log data
    fs.appendFileSync logfile, data+"\n\r"


  envir.on 'impulse-spike' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-spike.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    data = "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reports a spike of #{eventinfo.spike} units since last reported event"
    console.log data
    fs.appendFileSync logfile, data+"\r\n"

    #3
    fs.appendFileSync readlog, " " + eventinfo.spike + " *"


  envir.on 'impulse-correction' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-correction.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    data = "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reports a spike correction of #{eventinfo.newReading} units"
    console.log data
    fs.appendFileSync logfile, data+"\r\n"

    #4
    fs.appendFileSync readlog, " " + eventinfo.oldReading + " " + eventinfo.newReading 



 envir.on 'impulse-warning' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.impulse-warning.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    data = "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reports a spike warning. Reading reset to #{eventinfo.newReading} units"
    console.log data
    fs.appendFileSync logfile, data+"\r\n"

    #5
    fs.appendFileSync readlog, " " + eventinfo.newReading + " " + lastimp

 envir.on 'average' , (eventinfo) ->
#    console.log eventinfo
    db.publish "cc128.average.#{mapping.host}.#{mapping.device}", JSON.stringify( eventinfo) 
    data = "Sensor #{eventinfo.sensor}, channel #{eventinfo.channel} reports average of #{eventinfo.value} watts for #{eventinfo.type}:#{eventinfo.period} "
    console.log data
    fs.appendFileSync logfile, data+"\r\n"



    
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






