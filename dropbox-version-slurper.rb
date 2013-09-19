# Install this the SDK with "gem install dropbox-sdk"
require 'dropbox_sdk'
require 'parseconfig'
require 'FileUtils'
require 'diff/lcs'

config = ParseConfig.new('main.config')
APP_KEY = config['APP_KEY']
APP_SECRET = config['APP_SECRET']
ACCESS_TOKEN = config['ACCESS_TOKEN']
BRAIN = config['BRAIN']

target_file = ARGV.first
puts target_file
if (ACCESS_TOKEN == nil) then 
	flow = DropboxOAuth2FlowNoRedirect.new(APP_KEY, APP_SECRET)
	authorize_url = flow.start()

	# Have the user sign in and authorize this app
	puts '1. Go to: ' + authorize_url
	puts '2. Click "Allow" (you might have to log in first)'
	puts '3. Copy the authorization code'
	print 'Enter the authorization code here: '
	code = gets.strip

	# This will fail if the user gave us an invalid authorization code
	ACCESS_TOKEN, user_id = flow.finish(code)
	puts user_id + ':' + access_token
end

client = DropboxClient.new(ACCESS_TOKEN)
puts "linked account:", client.account_info().inspect

revisions = client.revisions(BRAIN + target_file)
puts 'Processing ' + revisions.count.to_s + ' revisions...'


FileUtils.mkdir_p('archive/' + target_file);

contents_previous = []

revisions.each do |revision| 
	d = DateTime.parse(revision['modified']).strftime("%Y-%m-%d-%H%M%S")
	begin
		puts 'Processing Revision ' + revision['rev'].to_s + ' modified on ' + d
		filename = './archive/' + target_file + '/' + d + '_' + target_file
		contents = ""
		if (!File.exists?(filename))
			contents, metadata = client.get_file_and_metadata(BRAIN + target_file, revision['rev'].to_s)
			open(filename, 'w') {|f| f.puts contents }
		else
			contents = File.readlines(filename)
		end
		#puts Diff::LCS.diff(contents_previous, contents).to_s
		#contents_previous = contents
	rescue Exception => e  
  		puts e.message  
  		puts e.backtrace.inspect  
	end  

end

s  = `cd ~/brain/; ~/scripts/git-cat.sh #{target_file} --relative-list`
puts "Processing " + (s.split("\n").count/2).to_s + " commits..."

s.split("\n").each do |line| 
	if (!line.start_with?('commit') && !line.start_with?('doing:'))
		puts ("Processing " + line)
		
		d = DateTime.parse(line.split('|')[1]).to_time.utc.strftime("%Y-%m-%d-%H%M%S")
		filename = './archive/' + target_file + '/' + d + '_g_' + target_file
		if (!File.exists?(filename))
			cmd = "cd ~/brain/; ~/scripts/git-cat.sh #{target_file} #{line.split('|')[0]} --no-log"
			contents = `#{cmd}`		
			open(filename, 'w') {|f| f.puts contents }
		end
		
	end
end

