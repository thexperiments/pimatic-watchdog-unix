# watchdog unix configuration options
module.exports = {
  title: "Options for watchdog unix plugin."
  type: "object"
  properties: {
    processScriptName:
      description: "Name of the script used to start pimatic (normally pimatic.js)"
      type: "string"
      default: "pimatic.js"
    processEnabled:
      description: "Enable/disable process running check"
      type: "boolean"
      default: false
    httpURL:
      description: "URL to use for http/https request"
      type: "string"
      default: "http://127.0.0.1:80/"
    httpTimeout:
      description: "Timeout for the http request (seconds)"
      type: "number"
      default: 60
    httpEnabled:
      description: "Enable/disable http request check"
      type: "boolean"
      default: false
    watchdogCycleTime:
      description: "Watchdog cycle time (seconds)"
      type: "number"
      default: 30
    watchdogRetries:
      description: "Number of retries to start pimatic after a hang/crash"
      type: "number"
      default: 3
    watchdogEnableReboot:
      description: "Enable/disable reboot after retry limit was exceeded"
      type: "boolean"
      default: false
  }
}