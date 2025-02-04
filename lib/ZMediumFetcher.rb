

$lib = File.expand_path('../lib', File.dirname(__FILE__))

require "fileutils"

require "Parsers/H1Parser"
require "Parsers/H2Parser"
require "Parsers/H3Parser"
require "Parsers/H4Parser"
require "Parsers/PParser"
require "Parsers/ULIParser"
require "Parsers/IframeParser"
require "Parsers/IMGParser"
require "Parsers/FallbackParser"
require "Parsers/BQParser"
require "Parsers/PREParser"
require "Parsers/MarkupParser"
require "Parsers/OLIParser"
require "Parsers/MIXTAPEEMBEDParser"
require "Parsers/PQParser"
require "Parsers/LinkParser"
require "Parsers/CodeBlockParser"

require "PathPolicy"
require "Request"
require "Post"
require "User"

class ZMediumFetcher

    attr_accessor :progress, :linkParser

    class Progress
        attr_accessor :username, :postPath, :currentPostIndex, :totalPostsLength, :currentPostParagraphIndex, :totalPostParagraphsLength, :message

        def printLog()
            info = ""
            if !username.nil?
                if !currentPostIndex.nil? && !totalPostsLength.nil?
                    info += "[#{username}(#{currentPostIndex}/#{totalPostsLength})]"
                else
                    info += "[#{username}]"
                end
            end

            if !postPath.nil?
                if info != ""
                    info += "-"
                end
                if !currentPostParagraphIndex.nil? && !totalPostParagraphsLength.nil?
                    info += "[#{postPath[0..10]}...(#{currentPostParagraphIndex}/#{totalPostParagraphsLength})]"
                else
                    info += "[#{postPath[0..10]}...]"
                end
            end

            if !message.nil?
                if info != ""
                    info += "-"
                end
                info += message
            end

            if info != "" 
                puts info
            end
        end
    end

    def initialize
        @progress = Progress.new()
        @linkParser = LinkParser.new(nil)
    end

    def buildParser(imagePathPolicy)
        h1Parser = H1Parser.new()
        h2Parser = H2Parser.new()
            h1Parser.setNext(h2Parser)
        h3Parser = H3Parser.new()
            h2Parser.setNext(h3Parser)
        h4Parser = H4Parser.new()
            h3Parser.setNext(h4Parser)
        ppParser = PParser.new()
            h4Parser.setNext(ppParser)
        uliParser = ULIParser.new()
            ppParser.setNext(uliParser)
        oliParser = OLIParser.new()
            uliParser.setNext(oliParser)
        mixtapeembedParser = MIXTAPEEMBEDParser.new()
            oliParser.setNext(mixtapeembedParser)
        pqParser = PQParser.new()
            mixtapeembedParser.setNext(pqParser)
        iframeParser = IframeParser.new()
        iframeParser.pathPolicy = imagePathPolicy
            pqParser.setNext(iframeParser)
        imgParser = IMGParser.new()
        imgParser.pathPolicy = imagePathPolicy
            iframeParser.setNext(imgParser)
        bqParser = BQParser.new()
            imgParser.setNext(bqParser)
        preParser = PREParser.new()
            bqParser.setNext(preParser)
        codeBlockParser = CodeBlockParser.new()
            preParser.setNext(codeBlockParser)
        fallbackParser = FallbackParser.new()
            codeBlockParser.setNext(fallbackParser)


        h1Parser
    end

    def downloadPost(postURL, pathPolicy)
        postID = Post.getPostIDFromPostURLString(postURL)
        postPath = Post.getPostPathFromPostURLString(postURL)

        progress.postPath = postPath
        progress.message = "Downloading Post..."
        progress.printLog()

        postHtml = Request.html(Request.URL(postURL))

        postContent = Post.parsePostContentFromHTML(postHtml)
        if postContent.nil?
            raise "Error: Content is empty! PostURL: #{postURL}"
        end
        
        postInfo = Post.parsePostInfoFromPostContent(postContent, postID)

        sourceParagraphs = Post.parsePostParagraphsFromPostContent(postContent, postID)
        if sourceParagraphs.nil?
            raise "Error: Paragraph not found! PostURL: #{postURL}"
        end 
        
        progress.message = "Formatting Data..."
        progress.printLog()

        paragraphs = []
        oliIndex = 0
        previousParagraph = nil
        preTypeParagraphs = []
        sourceParagraphs.each do |sourcParagraph|
            paragraph = Paragraph.new(sourcParagraph, postID, postContent)
            if OLIParser.isOLI(paragraph)
                oliIndex += 1
                paragraph.oliIndex = oliIndex
            else
                oliIndex = 0
            end

            # if previous is OLI or ULI and current is not OLI or ULI
            # than insert a blank paragraph to keep markdown foramt correct
            if (OLIParser.isOLI(previousParagraph) && !OLIParser.isOLI(paragraph)) ||
                (ULIParser.isULI(previousParagraph) && !ULIParser.isULI(paragraph))
                paragraphs.append(Paragraph.makeBlankParagraph(postID))
            end

            # group by PRE paragraph to code block
            # because medium will give continue pre to present code block
            # e.g.
            # type=pre, text=<html>
            # type=pre, text=text
            # type=pre, text=</html>
            
            if !previousParagraph.nil?
                if PREParser.isPRE(paragraph)
                    # if current is pre
                    preTypeParagraphs.append(paragraph)
                elsif PREParser.isPRE(previousParagraph) && !PREParser.isPRE(paragraph)
                    # if current is note pre and previousParagraph is pre and preTypeParagraphs > 1
                    if preTypeParagraphs.length > 1
                        lastPreTypeParagraph = preTypeParagraphs.pop

                        # group by preParagraphs text to last preParagraph
                        groupByText = ""
                        preTypeParagraphs.each do |preTypeParagraph|
                            if groupByText != ""
                                groupByText += "\n"
                            end

                            markupParser = MarkupParser.new(postHtml, preTypeParagraph)
                            groupByText += markupParser.parse()
                        end
                        
                        lastPreTypeParagraph.text = "#{groupByText}"
                        lastPreTypeParagraph.type = CodeBlockParser.getTypeString()
                        
                        # remove all preParagraphs
                        preTypeParagraphNames = preTypeParagraphs.map do |preTypeParagraph|
                            preTypeParagraph.name
                        end
                        paragraphs = paragraphs.select do |paragraph| 
                            !preTypeParagraphNames.include? paragraph.name
                        end
                    end
                    preTypeParagraphs = []
                end
            end

            paragraphs.append(paragraph)
            previousParagraph = paragraph
        end

        postPathPolicy = PathPolicy.new(pathPolicy.getAbsolutePath(nil), "posts")

        imagePathPolicy = PathPolicy.new(postPathPolicy.getAbsolutePath(nil), "images")
        startParser = buildParser(imagePathPolicy)

        progress.totalPostParagraphsLength = paragraphs.length
        progress.currentPostParagraphIndex = 0
        progress.message = "Converting Post..."
        progress.printLog()

        absolutePath = postPathPolicy.getAbsolutePath("#{postPath}.md")
        
        # if markdown file is exists and last modification time is >= latestPublishedAt(last update post time on medium)
        if File.file?(absolutePath) && File.mtime(absolutePath) >= postInfo.latestPublishedAt
            # Already downloaded and nothing has changed!, Skip!
            progress.currentPostParagraphIndex = paragraphs.length
            progress.message = "Skip, Post already downloaded and nothing has changed!"
            progress.printLog()
        else
            Helper.createDirIfNotExist(postPathPolicy.getAbsolutePath(nil))
            File.open(absolutePath, "w+") do |file|
                # write postInfo into top
                file.puts(Helper.createPostInfo(postInfo))
                
                index = 0
                paragraphs.each do |paragraph|
                    markupParser = MarkupParser.new(postHtml, paragraph)
                    paragraph.text = markupParser.parse()
                    result = startParser.parse(paragraph)
    
                    if !linkParser.nil?
                        result = linkParser.parse(result, paragraph.markupLinks)
                    end
                    
                    file.puts(result)
    
                    index += 1
                    progress.currentPostParagraphIndex = index
                    progress.message = "Converting Post..."
                    progress.printLog()
                end
    
                file.puts(Helper.createWatermark(postURL))
            end
            FileUtils.touch absolutePath, :mtime => postInfo.latestPublishedAt

            progress.message = "Post Successfully Downloaded!"
            progress.printLog()
        end
        
        progress.postPath = nil
    end
    
    def downloadPostsByUsername(username, pathPolicy)
        progress.username = username
        progress.message = "Fetching infromation..."
        progress.printLog()

        userID = User.convertToUserIDFromUsername(username)
        if userID.nil?
            raise "Medium's Username:#{username} not found!"
        end

        progress.message = "Fetching posts..."
        progress.printLog()

        postURLS = []
        nextID = nil
        begin
            postPageInfo = User.fetchUserPosts(userID, nextID)
            postPageInfo["postURLs"].each do |postURL|
                postURLS.append(postURL)
            end
            nextID = postPageInfo["nextID"]
        end while !nextID.nil?

        @linkParser = LinkParser.new(postURLS)

        progress.totalPostsLength = postURLS.length
        progress.currentPostIndex = 0
        progress.message = "Downloading posts..."
        progress.printLog()

        userPathPolicy = PathPolicy.new(pathPolicy.getAbsolutePath(nil), "users/#{username}")
        index = 0
        postURLS.each do |postURL|
            downloadPost(postURL, userPathPolicy)

            index += 1
            progress.currentPostIndex = index
            progress.message = "Downloading posts..."
            progress.printLog()
        end

        progress.message = "All posts has been downloaded!, Total posts: #{postURLS.length}"
        progress.printLog()
    end
end