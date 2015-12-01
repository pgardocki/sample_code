require 'rubygems'
require 'bundler/setup'

require 'json'
require 'rest-client'

host = 'http://job-queue-dev.elasticbeanstalk.com'

#
# Create a new game
#
game_json = RestClient.post("#{host}/games", { long: true }).body
game = JSON.parse(game_json)

#
# Machines array will store all created and terminated machine ids
# Machines hash- key: machine_id, value: [[job_memory, job_turns, job_id], [etc...]]
#
machines_arr = []
machines_hash = {}

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
  
  #
  # The following 3 values will be added to the machines hash 
  #
  memory = turn['jobs'].map { |job| job['memory_required'] }
  turns = turn['jobs'].map { |job| job['turns_required'] }
  ids = turn['jobs'].map { |job| job['id'] }
  
  #
  # Assign jobs to machines already created
  #
  if (machines_hash.count > 0)    
    machines_hash.each do |machine, jobs|        
    
      machine_memory = 0
      jobs.each {|job| machine_memory += job[0]}
      
      ids_to_add = []
      indexes_to_remove = []
      
      memory.count.times do |idx|
        next if (machine_memory + memory[idx] > 64)
        machine_memory += memory[idx]
        jobs << [memory[idx], turns[idx], ids[idx]]
        ids_to_add << ids[idx]
        indexes_to_remove << idx
      end
      
      indexes_to_remove.reverse.each do |idx|
        memory.delete_at(idx); turns.delete_at(idx); ids.delete_at(idx)
      end
    
      RestClient.post("#{host}/games/#{game['id']}/machines/#{machine}/job_assignments",
      job_ids: JSON.dump(ids_to_add)).body
    end
  end
    
  #
  # Assign 1 new job per machine going over the 64GB limit if
  # the machine will have the memory available in less turns than the new job turns
  #
  if ((machines_hash.count > 0) && (memory.count > 0))
    machines_hash.each do |machine, jobs|
      
      break if memory.count == 0
      
      machine_memory = 0
      jobs.each {|job| machine_memory += job[0]}      
      next if machine_memory > 64
      
      (memory.count - 1).downto(0) do |idx|
        
        break if machine_memory > 64
        
        new_job_memory = memory[idx]
        new_job_turns = turns[idx]
        new_job_id = ids[idx]
        
        memory_expiring_soon = 0
        jobs.each { |job| memory_expiring_soon += job[0] if (job[1] == 1) }
        
        if (memory_expiring_soon > new_job_memory)
          machine_memory += new_job_memory
          jobs << [memory[idx], turns[idx], ids[idx]]
          RestClient.post("#{host}/games/#{game['id']}/machines/#{machine}/job_assignments",
          job_ids: JSON.dump([new_job_id])).body
          memory.delete_at(idx); turns.delete_at(idx); ids.delete_at(idx)
        end
      end
      
    end
  end
  
  #
  # Make more machines if there are unassigned jobs remaining
  #
  if (memory.count > 0)
    
    total_memory = memory.inject(:+)
    new_machines = (total_memory / 64.0).ceil
    
    new_machines.times do
      machine_json = RestClient.post("#{host}/games/#{game['id']}/machines", {}).body
      machines_arr << (JSON.parse(machine_json))['id']
      machines_hash[machines_arr[-1]] = []
    end
   
    machines_hash.each do |machine, jobs|
          
      if (jobs.empty? && (memory.count > 0))
        memory_usage = 0
      
        indexes_to_remove = []
        
        memory.count.times do |idx|
          next if (memory_usage + memory[idx] > 64)
          memory_usage += memory[idx]
          jobs << [memory[idx], turns[idx], ids[idx]]
          indexes_to_remove << idx
        end
        
        indexes_to_remove.reverse.each do |idx|
          memory.delete_at(idx); turns.delete_at(idx); ids.delete_at(idx)
        end
      
        ids_to_add = []
        jobs.each {|job| ids_to_add << job[2]}
      
        RestClient.post("#{host}/games/#{game['id']}/machines/#{machine}/job_assignments",
        job_ids: JSON.dump(ids_to_add)).body
      end
            
    end    
  end
  
  #
  # Decrease turn value by 1 for each job in the hash
  #  
  machines_hash.each_value do |jobs|
    jobs.each do |job|
      job[1] -= 1
    end
  end
  
  #
  # If a job has a turn value of 0, delete the job from the array
  #
  machines_hash.each_value do |jobs|
    jobs.delete_if do |job|
      job[1] == 0
    end
  end
  
  #
  # Delete machines that have no jobs
  #
  machines_hash.each do |machine, jobs|
    if jobs.count == 0
      RestClient.delete("#{host}/games/#{game['id']}/machines/#{machine}")
      machines_hash.delete(machine)
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

puts "COMPLETED GAME WITH:"
puts "\n"
puts "Time Score: #{completed_game['time_score']} (Total delay: #{completed_game['delay_turns']} turns)"
puts "Cost Score: #{completed_game['cost_score']} (Total cost: $#{completed_game['cost']})"
puts "Total Score: #{completed_game['total_score']}"

