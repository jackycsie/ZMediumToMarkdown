FROM ruby:2.6.5

RUN mkdir -p /home/ZMediumToMarkdown/
WORKDIR /home/ZMediumToMarkdown
RUN gem install bundler:2.3.13

COPY Gemfile Gemfile.lock /home/ZMediumToMarkdown/
RUN cd /home/ZMediumToMarkdown/ && bundle update --bundler