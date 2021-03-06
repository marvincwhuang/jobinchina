require 'open-uri'

class AutoScrappingJob < ApplicationJob
  queue_as :default

  def perform
    # Do something later
    all_keywords = Dashboard.select(:hot_skills).map{|i|i.hot_skills}.flatten.delete_if{|n| n.class == Integer}

    all_keywords.each do |keyword|
        @search = Search.create!(keyword: keyword)
        @keyword = keyword.scan(/\w*/).join(" ").strip
        new(@keyword)

    end
  end

    def new(keyword)
        @keyword = keyword
        @search = Search.create!(keyword: @keyword)        
        if Dashboard.find_by(keyword: @keyword)
            puts "already be searched before"
        else
            puts "start scraping..."
            scraper(@search)
            @new_record = Dashboard.create!(keyword: @keyword)
            @new_record.average_salary = @search.average_salary
            @new_record.jobs = @search.jobs
            GetKeywordsJob.perform_later(@new_record.id)
            @jobs = @new_record.jobs
            @new_record.most_opportunities = location_qty(@jobs)
            @new_record.highest_paying = location_salary(@jobs)
            @new_record.save
        end 


    end

private

def search_params
    params.require(:search).permit(:keyword)
end

def scraper(search)
    puts search
    @search = search
    jobs = []
    page = 1
    total_page = nil

    loop do 
        url = "https://search.51job.com/list/000000,000000,0000,00,9,99,#{@search.keyword},2,#{page}.html?lang=c&stype=&postchannel=0000&workyear=99&cotype=99&degreefrom=99&jobterm=99&companysize=99&providesalary=99&lonlat=0%2C0&radius=-1&ord_field=0&confirmdate=9&fromType=&dibiaoid=0&address=&line=&specialarea=00&from=&welfare="
        url = URI.parse(URI.escape(url)) # 避免輸入中文錯誤: URI must be ascii only
        html_data = open(url).read
        nokogiri_object = Nokogiri::HTML(html_data, nil, 'GBK') # encode: GBK!
        if total_page.nil?
            total_page = nokogiri_object.css("div.p_in > span.td").text.match('\d')[0].to_i
        end

        titles = nokogiri_object.css("div.el > p.t1 > span > a").map { |element| element['title'] }
        title_links = nokogiri_object.css("div.el > p.t1 > span > a").map { |element| element['href'] }
        companys = nokogiri_object.css("div.el > span.t2").map { |element| element.text }
        company_links = nokogiri_object.css("div.el > span.t2 > a").map { |element| element['href'] }
        locations = nokogiri_object.css("div.el > span.t3").map { |element| element.text }
        salaries = nokogiri_object.css("div.el > span.t4").map { |element| element.text }
        dates = nokogiri_object.css("div.el > span.t5").map { |element| element.text }

        (0...titles.size).each do |i|
            job = {name: titles[i], url: title_links[i], company: companys[i+1], location: locations[i+1], salary: salary_converter(salaries[i+1]), search_id: @search[:id], keyword: @search[:keyword]}
            @job = Job.new(job)
            @search.jobs << @job
        end

        @search.average_salary = get_average_salary(@search.jobs)
        @search.save
        page < total_page ? page += 1 : break
    end

    puts "finish scrappign jobs. Search results: "
    puts @search
end

def salary_converter(salary)
    return nil if salary.empty?
    value_s = salary.match('(\d?|\S?)*\B')[0]
    unit_s = salary.sub(value_s, "")
    value = value_s.split("-").map {|item| item.to_f}
    if unit_s == '万/月'
        unit = 10000
    elsif unit_s == '千/月' 
        unit = 1000
    elsif unit_s == '万/年'
        unit = 10000 / 12
    elsif unit_s == '元/天'
        unit = 30
    else 
        return nil
    end
    salary = (value.sum / value.size * unit).round(2) # RMB / month"
end

def get_average_salary(jobs)
    #caculate average salary
    unless jobs.empty?
        salaries = jobs.map { |job| job[:salary] }.select { |salary| !salary.nil? }
        average = (salaries.sum / salaries.size).round(2)
    end
end

def location_qty(jobs)
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

def location_qty_percentage(jobs)
    job_qty = jobs.size
    location_qty = location_qty(jobs)
    location_qty_percentage = location_qty.map { |pair| [pair[0], (pair[1].to_f / job_qty * 100).round(2)] }
end

def location_salary(jobs)
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
end

  
  
  