require 'pry'
require 'csv'
require 'json'
require './comment'

def gen_aff_files(csv_file)
  # Process affiliations found by Python cncf/gitdm saved in CSV
  # "email","name","company","date_to"
  comps = {}
  emails = {}
  names = {}
  dt_now = DateTime.now.to_date.to_s
  dt_future = DateTime.now.next_year.to_date.to_s
  CSV.foreach(csv_file, headers: true) do |row|
    next if is_comment row
    h = row.to_h
    c = h['company'].strip
    e = h['email'].strip
    n = h['name'].strip
    d = h['date_to'].strip
    h['date_to'] = d = dt_future if !d || d == ''
    next unless e.include?('@')
    names[n] = {} unless names.key?(n)
    names[n][e] = [] unless names[n].key?(e)
    names[n][e] << h
    emails[e] = [] unless emails.key?(e)
    emails[e] << h
    comps[c] = {} unless comps.key?(c)
    comps[c][n] = {} unless comps[c].key?(n)
    comps[c][n][e] = [] unless comps[c][n].key?(e)
    comps[c][n][e] << h
  end

  wrongs = []
  w = []
  t = ''
  comps.keys.sort.each do |comp_name|
    devs = comps[comp_name]
    t += "#{comp_name}:\n"
    devs.keys.sort.each do |dev_name|
      email_list = names[dev_name]
      affs = []
      affse = []
      email_list.keys.sort.each do |email|
        affs << emails[email].map { |a| [a['company'], a['date_to']] }.sort_by { |r| r[1] }.reverse
        affse << emails[email].map { |a| [a['email'], a['company'], a['date_to']] }.sort_by { |r| r[2] }.reverse
      end
      # Very important sanity check
      if affs.uniq.count > 1
        h = {}
        h[dev_name] = affse
        wrongs << JSON.pretty_generate(h)
        w << [dev_name, affse]
      end
      ems = {}
      affs.each_with_index do |aff, idx|
        k = aff.clone
        ems[k] = [] unless ems.key?(k)
        ems[k] << affse[idx].first[0]
      end
      ems.each do |affl, lst|
        has_dev = affl.map { |aff| aff[0] }.include?(comp_name)
        next unless has_dev
        t += "\t#{dev_name}: #{lst.sort.join(', ')}"
        len = affl.length
        dates = []
        affl.each_with_index do |aff, index|
          next unless aff[0] == comp_name
          from = ''
          if index != len - 1
            from = "from #{affl[index + 1][1]}"
          end
          to = aff[1] == dt_future ? '' : "until #{aff[1]}"
          dates << [from, to].reject { |d| d == '' }.join(' ')
        end
        datestr = dates.reverse.join(', ')
        datestr = ' ' + datestr unless datestr == ''
        t += "#{datestr}\n"
      end
    end
  end
  File.write 'company_developers.txt', t

  t = ''
  names.keys.sort.each do |dev_name|
    email_list = names[dev_name]
    affs = []
    affse = []
    email_list.keys.sort.each do |email|
      affs << emails[email].map { |a| [a['company'], a['date_to']] }.sort_by { |r| r[1] }.reverse
      affse << emails[email].map { |a| [a['email'], a['company'], a['date_to']] }.sort_by { |r| r[1] }.reverse
    end
    ems = {}
    split = affs.uniq.count == 1 ? '' : '*'
    affs.each_with_index do |aff, idx|
      k = aff.clone
      ems[k] = [] unless ems.key?(k)
      ems[k] << affse[idx].first[0]
    end
    ems.each do |affl, lst|
      t += "#{dev_name}#{split}: #{lst.sort.join(', ')}\n"
      affl.each do |aff|
        datestr = aff[1] == dt_future ? '' : " until #{aff[1]}"
        t += "\t#{aff[0]}#{datestr}\n"
      end
    end
  end
  File.write 'developers_affiliations.txt', t

  if wrongs.count > 0
    wrongs = wrongs.uniq
    w = w.uniq
    e = w.select { |r| r[1].any? { |a| a.length > 1 } } # With more than 1 affiliation on any email
    s = w.select { |r| r[1].count > 2 }                 # With more than 2 emails
    nf = w.select { |r| r[1].any? { |a| a.any? { |b| b[1] == 'NotFound' } } }
    se = w.select { |r| r[1].any? { |a| a.any? { |b| b[1] == 'Self' } } }
    un = w.select { |r| r[1].any? { |a| a.any? { |b| b[1] == '(Unknown)' } } }
    dt = w.select { |r| r[1].any? { |a| a.any? { |b| b[2] != dt_future } } }
    # binding.pry
    puts 'Special cases found, consider binding.pry it!'
  end
end

if ARGV.size < 1
  puts "Missing argument: CSV_file (all_affs.csv)"
  exit(1)
end

gen_aff_files(ARGV[0])