# #Plugin template

# This is an plugin template and mini tutorial for creating pimatic plugins. It will explain the 
# basics of how the plugin system works and how a plugin should look like.

# ##The plugin code
# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an environment object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Include you own dependencies with nodes global require function:
  #  
  #     someThing = require 'someThing'
  #  
  spawn = require('child_process').spawn
  fs = require 'fs' 
  path = require 'path'

  class WatchdogUnix extends env.plugins.Plugin

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 

    init: (app, @framework, @config) =>
      env.logger.info("Starting pimatic-watchdog-unix plugin")

      @processScriptName = @config.processScriptName
      @processEnabled = @config.processEnabled
      @httpURL = @config.httpURL
      @httpTimeout = @config.httpTimeout
      @httpEnabled = @config.httpEnabled
      @watchdogCycleTime = @config.watchdogCycleTime
      @watchdogRetries = @config.watchdogRetries
      @watchdogEnableReboot = @config.watchdogEnableReboot

      @workingDirPath = path.resolve @framework.maindir, '../../watchdog-data'
      #create data dir if not existing
      if !fs.existsSync(@workingDirPath)
        fs.mkdirSync(@workingDirPath)

      @pluginPath = path.resolve @framework.maindir, "../pimatic-watchdog-unix"
      @scriptPath = path.join(@pluginPath, 'pimatic-watchdog-unix.sh')
      #make script executable
      if fs.existsSync(@scriptPath)
        env.logger.debug "make #{@scriptPath} executable"
        fs.chmodSync(@scriptPath, 0o777)

      @framework.once "after init", =>
        #only starting the watchdog after a sucessfull startup

        #creating output files to be able to completely detatch process
        stdErrFile = fs.openSync path.join(@workingDirPath, './error.log'), 'a'
        #stdOutFile = fs.openSync path.join(@workingDirPath, './error.log'), 'a'
        stdOutFile = fs.openSync '/dev/null', 'a'

        args = ["--scriptName", "#{@processScriptName}",
          "#{if @processEnabled then '--processEnabled' else ''}",
          "--httpURL", "#{@httpURL}",
          "--httpTimeout", "#{@httpTimeout}",
          "#{if @httpEnabled then '--httpEnabled' else ''}",
          "--watchdogCycleTime", "#{@watchdogCycleTime}"
          "--watchdogRetries", "#{@watchdogRetries}",
          "#{if @watchdogEnableReboot then '--watchdogEnableReboot' else ''}"]

        env.logger.debug "Starting watchdog with args = #{args}"

        child = spawn(@scriptPath, args, {
          detached: true,
          stdio: [ 'ignore', stdOutFile, stdErrFile ],
          cwd: @workingDirPath
        })

        child.unref()


  # ###Finally
  # Create a instance of my plugin
  myWatchdogUnix = new WatchdogUnix
  # and return it to the framework.
  return myWatchdogUnix
