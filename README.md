CCEE2REDISPUB
=============

CCXMLEventEmitter to Redis Publishing Bridge

Publishes CCXMLEventEmitter events to redis publishing channels so the events can be picked up by remote processes.

This small program exists because I had a need to process "Current Cost" data remotely from where I was capturing it.
My need therefore was to get the "Current Cost" XML data from the base station via Serial connection out onto my local network
in in a fairly modular way. As I use Redis to process/store local and remote data, it seemed a good fit to use it as 
a pub/sub transport to get the data to where I could process it. This simple solution allows me to process data from numerous 
"Current Cost" devices that are geographically dispersed, yet internet connected. This module does not 'process' any of 
the "Current Cost" data, it simply uses Redis to broadcast events from the serially connected devices. 

You could also use this mechanism to keep all your processes on a single host and simply use Redis as your interprocess 
transport mechanism. 
i.e.

Current Cost Device -> Serial -> EventEmitter -> EventConsumer -> Redis Publish -> Redis Subscribe -> local processing.

vs

Current Cost Device -> Serial -> EventEmitter -> EventConsumer -> Redis Publish -> NETWORK -> Redis Subscribe -> local processing.

Usage:
