require 'rubygems'
require 'bundler/setup'

require 'json'
require 'rest-client'

host = 'http://job-queue-dev.elasticbeanstalk.com'

#
# Create a new game
#
game_json = RestClient.post("#{host}/games", {}).body
game = JSON.parse(game_json)

# 
# Create a new machine
#
machine_one_json = RestClient.post("#{host}/games/#{game['id']}/machines", {}).body
machine_one = JSON.parse(machine_one_json)

#
# Create more machines (total machines will be num_machines + 1)
# Just change num_machines and run program to get results!
#
num_machines = 7
(num_machines).times do 
  RestClient.post("#{host}/games/#{game['id']}/machines", {}).body
end

#
# Store all machine ids in an array
#
machines_arr = (machine_one['id']..(machine_one['id'] + num_machines)).to_a

#
# Pull the data for the next turn. This will include the jobs to be
# scheduled as well as the current status of the game.
#
turn_json = RestClient.get("#{host}/games/#{game['id']}/next_turn").body
turn = JSON.parse(turn_json)


status = turn['status']
jobs_found = turn['jobs'].count

while (status != 'completed')
  
  puts "On turn #{turn['current_turn']}, got #{turn['jobs'].count} jobs,
  having completed #{turn['jobs_completed']} of #{jobs_found} with
  #{turn['jobs_running']} jobs running, #{turn['jobs_queued']} jobs queued,
  and #{turn['machines_running']} machines running"

  job_ids = turn['jobs'].map { |job| job['id'] }
  new_jobs = job_ids.count
  
  #
  # Create multiple empty arrays to store jobs
  #  
  jobs_arr = Array.new(num_machines + 1) { Array.new([]) }
  
  #
  # If there are new jobs, assign them
  #
  if new_jobs > 0
    
    #
    # Jobs are added one at a time to successive array in jobs array
    #      
    job_ids.each do |job_id|      
      jobs_arr[(job_id % (num_machines + 1))] << job_id
    end
    
    #
    # Each machine is assigned its own set of jobs from jobs array 
    # 
    jobs_arr.each_with_index do |job_arr, index|
      next if job_arr.empty?
      RestClient.post("#{host}/games/#{game['id']}/machines/#{machines_arr[index]}/job_assignments",
      job_ids: JSON.dump([job_arr])).body
    end
  end

  turn_json = RestClient.get("#{host}/games/#{game['id']}/next_turn").body
  turn = JSON.parse(turn_json)

  jobs_found += turn['jobs'].count

  status = turn['status']
end

game_json = RestClient.get("#{host}/games/#{game['id']}",).body
puts game_json
puts "\n\n"

completed_game = JSON.parse(game_json);

puts "COMPLETED GAME WITH #{num_machines + 1} total machines:"
puts "\n"
puts "Time Score: #{completed_game['time_score']} (Total delay: #{completed_game['delay_turns']} turns)"
puts "Cost Score: #{completed_game['cost_score']} (Total cost: $#{completed_game['cost']})"
puts "Total Score: #{completed_game['total_score']}"

