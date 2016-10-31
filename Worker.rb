#!/home/ec2-user/.rvm/rubies/ruby-2.3.0/bin/ruby
require 'rubygems'
require 'aws-sdk'
require 'heroku-api'
require 'logging'

logger = Logging.logger(STDOUT)
logger.level = :info
heroku = Heroku::API.new(:api_key => '1c0f985e-4bf2-48cc-935d-cc8714c5a17b')
sqs = Aws::SQS::Client.new(region: "us-west-2")


qurl=sqs.get_queue_url({
        queue_name: "vidcon_queue"
        })

resp = sqs.get_queue_attributes({
  attribute_names: ["All"],
  queue_url: qurl['queue_url']
})

heroku.post_ps_scale('vidconworker', 'worker', 2) 
loop do

logger.info resp.attributes['ApproximateNumberOfMessages']
logger.info heroku.get_app('vidconworker').body['dynos']
logger.info heroku.get_app('vidconworker').body['workers']

sleep 5
end

 


