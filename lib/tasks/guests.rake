namespace :guests do
  desc 'Add an address, or @domain for everyone at a domain: bin/rails "guests:add[ana@example.com]" ("guests:add[ana@example.com,admin]" for the admin page)'
  task :add, %i[pattern role] => :environment do |_, args|
    guest = Guest.find_or_initialize_by(pattern: args[:pattern].to_s.strip.downcase)
    guest.admin = args[:role] == "admin"
    abort guest.errors.full_messages.to_sentence unless guest.save

    puts "#{guest.pattern} is on the guest list#{' (admin)' if guest.admin}"
  end

  desc 'Remove an entry from the guest list; people it let in lose access at once: bin/rails "guests:remove[ana@example.com]"'
  task :remove, %i[pattern] => :environment do |_, args|
    guest = Guest.where(pattern: args[:pattern].to_s.strip.downcase).first
    abort "#{args[:pattern]} is not on the guest list" unless guest

    guest.delete
    puts "Removed #{guest.pattern}"
  end

  desc "Show the guest list"
  task list: :environment do
    Guest.order(created_at: :asc).each do |guest|
      puts [ guest.pattern, (guest.admin ? "admin" : "guest"), guest.created_at.utc.strftime("%Y-%m-%d") ].join("  ")
    end
  end
end
