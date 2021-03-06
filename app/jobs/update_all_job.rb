class UpdateAllJob < ApplicationJob
  queue_as :default

  def perform
    # Do something later

    Search.all.each do |search|
      puts "///////////////////////////////////////////////////////////"
      puts "search id : #{search.id}"
      puts "search ketword #{search.keyword}"
      puts "search jobs : #{search.jobs} empty? #{search.jobs.empty?}"
      
      # if search has related jobs, create find coreesponfing dashboard and create jobsummary
      #  update dashboard data
      unless search.jobs.empty?
          @dashboard = Dashboard.find_by(keyword: search.keyword)
          puts "dashboard found... #{@dashboard.id}"
  
          puts "Now create jobSummary"
          @job_summary = JobSummary.create!(search_id: search.id)
          @job_summary.qty = search.jobs.size
          @job_summary.average_salary = get_average_salary(search.jobs)
          @job_summary.location_qty = location_qty(search.jobs)
          @job_summary.location_salary =  location_salary(search.jobs)
          @job_summary.url = search.jobs.map{|job| job[:url]}
          @job_summary.keyword = search.keyword
          @job_summary.save
          puts "Now has job summary ... #{@job_summary.id}"
  
          puts "update dashboard data..."
          @dashboard.average_salary = search.job_summary.average_salary
          @dashboard.job_qty = search.job_summary.qty
          @dashboard.most_opportunities = search.job_summary.location_qty
          @dashboard.highest_paying = search.job_summary.location_salary
          @dashboard.save
      end
    end
  end
end


def get_average_salary(jobs)
  puts "get average salary"
  #caculate average salary
  unless jobs.empty?
      salaries = jobs.map { |job| job[:salary] }.select { |salary| !salary.nil? }
      average = (salaries.sum / salaries.size).round(2)
  end
end

def location_qty(jobs)
  puts "get location qty"
  location_qty = {}
  jobs.each do |job|
      location = job[:location].split("-").first
      if location_qty[location].nil?
          location_qty[location] = 1
      else 
          location_qty[location] += 1
      end
  end
  location_qty.sort_by{|k, v| v}.reverse.to_a
end

def location_salary(jobs)
  puts "get location qty"
  location_salary = {}
  jobs.each do |job|
      unless job[:salary].nil?
          location = job[:location].split("-").first
          if location_salary[location].nil?
              location_salary[location] = [job[:salary]]
          else 
              location_salary[location] << job[:salary]
          end
      end
  end
  location_salary.select{|k,v| v.size > 3 }.map {|k, v|[k, (v.sum/v.size).round(2)]}.sort_by {|k,v| v}.reverse
  # need at least 3 data per location
end
