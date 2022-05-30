$lib = File.expand_path('../lib', File.dirname(__FILE__))

require 'fileutils'
require 'date'
require 'PathPolicy'
require 'Post'
require "Request"
require 'json'
require 'open-uri'
require 'zip'

class Helper

    class Version
        attr_accessor :major, :minor, :patch

        def initialize(major, minor, patch)
            @major = major.to_i
            @minor = minor.to_i
            @patch = patch.to_i
        end

        def to_string()
            "#{major.to_s}.#{minor.to_s}.#{patch.to_s}"
        end
    end

    def self.createDirIfNotExist(dirPath)
        dirs = dirPath.split("/")
        currentDir = ""
        begin
            dir = dirs.shift
            currentDir = "#{currentDir}/#{dir}"
            Dir.mkdir(currentDir) unless File.exists?(currentDir)
        end while dirs.length > 0
    end

    def self.makeWarningText(message)
        puts "####################################################\n"
        puts "#WARNING:\n"
        puts "##{message}\n"
        puts "#--------------------------------------------------#\n"
        puts "#Please feel free to open an Issue or submit a fix/contribution via Pull Request on:\n"
        puts "#https://github.com/ZhgChgLi/ZMediumToMarkdown\n"
        puts "####################################################\n"
    end

    def self.downloadLatestVersion()
        apiPath = 'https://api.github.com/repos/ZhgChgLi/ZMediumToMarkdown/releases'
        versions = JSON.parse(Request.URL(apiPath).body).sort { |a,b| b["id"] <=> a["id"] }

        version = nil
        index = 0
        while version == nil do
            thisVersion = versions[index]
            if thisVersion["prerelease"] == false
                version = thisVersion
                next
            end
            index += 1
        end
        
        zipFilePath = version["zipball_url"]
        puts "Downloading latest version from github..."
        open('latest.zip', 'wb') do |fo|
            fo.print open(zipFilePath).read
        end

        puts "Unzip..."
        Zip::File.open("latest.zip") do |zipfile|
            zipfile.each do |file|
                fileNames = file.name.split("/")
                fileNames.shift
                filePath = fileNames.join("/")
                if filePath != ''
                    puts "Unzinp...#{filePath}"
                    zipfile.extract(file, filePath) { true }
                end
            end
        end
        File.delete("latest.zip")

        tagName = version["tag_name"]
        puts "Update to version #{tagName} successfully!"
    end

    def self.createPostInfo(postInfo)
        result = "---\n"
        result += "title: #{postInfo.title}\n"
        result += "author: #{postInfo.creator}\n"
        result += "date: #{postInfo.firstPublishedAt.strftime('%Y-%m-%dT%H:%M:%S.%LZ')}\n"
        result += "tags: [#{postInfo.tags.join(",")}]\n"
        result += "---\n"
        result += "\r\n"

        result
    end

    def self.printNewVersionMessageIfExists() 
        if Helper.compareVersion(Helper.getRemoteVersionFromGithub(), Helper.getLocalVersionFromGemspec())
            puts "##########################################################"
            puts "#####           New Version Available!!!             #####"
            puts "##### Please type `bin/ZMediumToMarkdown -n` to update!!##"
            puts "##########################################################"
        end
    end

    def self.getLocalVersionFromGemspec()
        rootPath = File.expand_path('../', File.dirname(__FILE__))
        gemspecContent = File.read("#{rootPath}/ZMediumToMarkdown.gemspec")
        result = gemspecContent[/(gem\.version){1}\s+(\=)\s+(\'){1}(\d+(\.){1}\d+(\.){1}\d+){1}(\'){1}/, 4]

        if !result.nil?
            versions = result.split(".")
            Version.new(versions[0],versions[1],versions[2])
        else
            nil
        end
    end

    def self.getRemoteVersionFromGithub()
        apiPath = 'https://api.github.com/repos/ZhgChgLi/ZMediumToMarkdown/releases'
        versions = JSON.parse(Request.URL(apiPath).body).sort { |a,b| b["id"] <=> a["id"] }

        tagName = nil
        index = 0
        while tagName == nil do
            thisVersion = versions[index]
            if thisVersion["prerelease"] == false
                tagName = thisVersion["tag_name"]
                next
            end
            index += 1
        end

        if !tagName.nil?
            versions = (tagName.downcase.gsub! 'v','') .split(".")
            Version.new(versions[0],versions[1],versions[2])
        else
            nil
        end
    end

    def self.compareVersion(version1, version2)
        if version1.major > version2.major
            true
        else
            if version1.minor > version2.minor
                true
            else
                if version1.patch > version2.patch
                    true
                else
                    false
                end
            end
        end
    end

        
    def self.createWatermark(postURL)
        text = "\r\n\r\n\r\n"
        text += "+-----------------------------------------------------------------------------------+"
        text += "\r\n"
        text += "\r\n"
        text += "| **[View original post on Medium](#{postURL}) - Converted by [ZhgChgLi](https://blog.zhgchg.li)/[ZMediumToMarkdown](https://github.com/ZhgChgLi/ZMediumToMarkdown)** |"
        text += "\r\n"
        text += "\r\n"
        text += "+-----------------------------------------------------------------------------------+"
        text += "\r\n"
        
        text
    end
end