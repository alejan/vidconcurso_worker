#!/home/ec2-user/.rvm/rubies/ruby-2.3.0/bin/ruby
require 'rubygems'
#require 'active_record'
#require  'mysql2'
require 'streamio-ffmpeg'
require 'mail'
require 'aws-sdk'
require 'sendgrid-ruby'
require 'heroku-api'
include SendGrid

heroku = Heroku::API.new(:api_key => '1c0f985e-4bf2-48cc-935d-cc8714c5a17b')
#heroku = Heroku::API.new(:password => '1c0f985e-4bf2-48cc-935d-cc8714c5a17b')
#heroku = Heroku::API.new(:headers => {'User-Agent' => 'custom'}) 
heroku.delete_addon('vidconworker', 'papertrail')
puts  heroku.get_apps
puts heroku.get_user 

s3 = Aws::S3::Client.new(region:"us-west-2")
dynamoDB = Aws::DynamoDB::Resource.new(region: "us-west-2")
sqs = Aws::SQS::Client.new(region: "us-west-2")
vidclip = dynamoDB.table("vidclip")

qurl=sqs.get_queue_url({
        queue_name: "vidcon_queue"
        })
poller = Aws::SQS::QueuePoller.new(qurl['queue_url'], client:  sqs)

poller.poll do |message|
msg=message.message_attributes['uploaded'].string_value

puts msg


FileUtils.mkdir_p Dir.pwd+"/uploads/"+msg.split('/')[0..2].join('/')
puts "dir /uploa/#{msg.split('/')[0..2].join('/')} created" 
FileUtils.mkdir_p Dir.pwd+"/"+msg.split('/')[0..2].join('/') 
puts "dir /#{msg.split('/')[0..2].join('/')} created"

s3.get_object(
                response_target: Dir.pwd+"/uploads/" +msg,
                bucket: "vidconbanner",
                key:  msg
                )

movie = FFMPEG::Movie.new(Dir.pwd+'/uploads/'+msg)

movie.transcode(Dir.pwd+"/"+msg+".flv") do |progress|

if progress == 1
 o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
 string = (0...50).map { o[rand(o.length)] }.join
 string = '/video/show/converted/' + string
 
 vid=vidclip.scan({
	  select: "ALL_ATTRIBUTES",
	   scan_filter: {
		"url"=> {
		attribute_value_list: [msg],
		comparison_operator: "EQ"
		
		}}})

vidclip.update_item({
		key:{
		"preview_url" =>vid.items[0]['preview_url'] 
		},
		attribute_updates: {
   		"progress" => {
      			value: "convertido", # value <Hash,Array,String,Numeric,Boolean,IO,Set,nil>
      			action: "PUT", # accepts ADD, PUT, DELETE
    		},
		"converted_url" =>{
			value: string,
			action: "PUT"
		},
		"bucket_url" => {
			value: "vidclip/converted/"+msg.split('/')[2]+"/"+File.basename(msg)+".flv",
			action: "PUT"
		}	
	}})
converted = File.open(Dir.pwd+"/"+msg+".flv","r")
s3.put_object({
	 acl:"public-read",
         body: converted,
#	grant_read: "GrantRead",
#  	grant_read_acp: "READ_ACP",
#	 grant_full_control: "GrantFullControl",
         bucket: "vidconbanner",
         key: "vidclip/converted/"+msg.split('/')[2]+"/"+File.basename(msg)+".flv"
                        })
jmail=vid.items[0]['video_id']
hash = eval('{
  "personalizations": [
    {
      "to": [
        {
          "email": jmail
        }
      ],
      "subject": "vidconcurso"
    }
  ],
  "from": {
    "email": "a.quintero10@uniandes.edu.co"
  },
  "content": [
    {
      "type": "text/plain",
      "value": "su video se convirtio!"
    }
  ]
}')
data = JSON.parse(hash.to_json)

sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
response = sg.client.mail._("send").post(request_body: data)
puts response.status_code
puts response.body
puts response.headers

FileUtils.rm_rf(Dir.pwd+"/uploads/"+msg.split('/')[0..2].join('/'))
FileUtils.rm_rf(Dir.pwd+"/"+msg.split('/')[0..2].join('/'))

end
end

end


 


