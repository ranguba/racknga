# NEWS

## 0.9.5: 2024-04-08

### Improvments

  * Added `base64` dependency.
  * Added `net-smtp` dependency.
  * Removed `nkf` dependency.
  * Stopped using deprecated APIs of Rack.

## 0.9.4: 2023-09-03

### Improvments

  * [cache] Made Rroonga dependency optional. Users must add Rroonga
    dependency explicitly.
  * And more improvements...

## 0.9.3: 2011-11-12

### Improvments

  * [access-log-parser] Supported Apache log.
  * [cache] Fixed unknown name errors.
  * [cache] Fixed max age.
  * [nginx] Added NginxRawURI middleware.
  * [instance-name] Added branch name and Ruby version.
  * [exception-mail-notifier] Used #message instead of #to_s.
  * [logger] Logged also X-Runtime.

## 0.9.2: 2011-08-07

### Improvments

  * [munin] Supported Passenger 3 support.
  * [munin] Removed Passenger 2 support.
  * [middleware][jsonp] Improved browser compatibility by using
    "text/javascript" for Content-Type.
  * [middleware][cache] Improved checksum robustness by using
    SHA1 instead of MD5.
  * [middleware][cache] Supported 4096 >= length URL.
  * [exception-mail-notifier] Supported limited mailing.
  * [middleware][instance-name] Added.
  * Added NginixAccessLogParser.
  * Documented middlewares.

## 0.9.1: 2010-11-11

  * Improved cache validation.
  * Supported caches per User-Agent.
  * Added a JSONP middleware.
  * Added a HTTP Range support middleware.
  * Added a logging access to groogna databsae middleware.
  * Added Munin plugins for Passenger.
  * Changed license to LGPLv2.1 or later from LGPLv2.1.
  * Supported will_paginate.

## 0.9.0: 2010-07-04

  * Initial release!
