#!/usr/bin/ruby

#
# Automatically download all the PDFs on a cairn's page using the user's cookies for auth.
# Written by Thomas Charbonnel, Feb. 2015.
# BSD License.
#

require 'optparse'
require 'rubygems'
require 'json'
require 'net/http'
require 'uri'
require 'hpricot'

def get_url(url, cookies_str, referer = "")
  http = Net::HTTP.new("89.185.38.44")
  req = Net::HTTP::Get.new(url)

  req["Cookie"] = cookies_str
  req["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.94 Safari/537.36"
  req["Host"] = "www.cairn.info"
  req["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
  req["Accept-Encoding"] = "gzip, deflate, sdch"
  req["Accept-Language"] = "en-US,en;q=0.8,fr-FR;q=0.6,fr;q=0.4"
  req["X-Forwarded-For"] = "160.68.205.231"
  req["Referer"] = referer
  req["Connection"] = "keep-alive"

  return http.request(req).body
end

# Let's first parse the options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cairn_dl.rb [options]"

  opts.on('-u', '--url URL', 'URL')                               { |v| options[:url] = v }
  opts.on('-c', '--cookies COOKIES_FILE', 'Cookies file in JSON') { |v| options[:cookies] = v }
  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end.parse!

# An URL must be given for the script to work.
options[:cookies] ||= "cookies.json"
unless options[:url]
  puts "No URL was given."
  exit!
end

# Now we take care of the cookies by loading them from an external json file.
cookies = JSON.parse(File.read(options[:cookies]))
cookies_str = ''
cookies.each do |cookie|
  cookies_str += cookie["name"] + '=' + cookie["value"] + '; '
end

# We GET the HTML page.
uri = URI.parse(options[:url])

# Creating issue's folder
issue_folder_name = uri.path[1..-5]
begin
  Dir.mkdir(issue_folder_name)
rescue Errno::EEXIST
  puts "The folder already exists."
end
Dir.chdir(issue_folder_name)

# Save the current html page as a reference
page = get_url(uri.request_uri, cookies_str)
page_file = File.open(issue_folder_name + ".html", "wb")
page_file << page
page_file.close

# Fetch each article
doc = Hpricot(page)
articles = doc.search("//div[@class='list_articles']").search("//div[@class='article greybox_hover']").each do |article|
  article_id = article.attributes['id']

  file = File.open(article_id + ".pdf", "wb")
  file << get_url('http://www.cairn.info/load_pdf.php?ID_ARTICLE=' + article_id, cookies_str, options[:url])
  file.close
end
