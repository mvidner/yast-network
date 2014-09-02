# encoding: utf-8

require "yast"
module Yast
  # Stores the mapping between hardware (identified by a modalias)
  # and its driver.
  module DriverMappingStore

    PATH = Yast::Path.new ".udev_persistent.drivers"

    # @return Hash{String => String} mapping from modalias to driver
    def read
      udev_drivers_rules = SCR.Read(PATH) || []
      mapping = {}
      udev_drivers_rules.each do |modalias, rule_items|
        driver = rule_items[1].split("=").last.delete('"')
        mapping[modalias] = driver
      end
      mapping
    end
    module_function :read

    # @param mapping Hash{String => String} mapping from modalias to driver
    def write(mapping)
      udev_drivers_rules = {}
      mapping.each do |modalias, driver|
        udev_drivers_rules[driver] = [
          "ENV{MODALIAS}==\"#{modalias}\"",
          "ENV{MODALIAS}=\"#{driver}\""
        ]
      end
      Builtins.y2milestone("write drivers udev rules: %1", udev_drivers_rules)

      SCR.Write(PATH, udev_drivers_rules)
    end
    module_function :write

  end
end
