require 'CSV'
require 'FileUtils'
###LATEST ISSUES
# "Add button working great"
# List buttons working upon boot but have a lil bit of trouble showing changes after I add into program.
#Biggest problem right now is "delete" button. Copiestask to "removed" folder; but doesn't work like it does in the command line version in corefile.rb. Currently tried different approach without fileutils but getting little to no response.
#login page currently disabled to debug quicker.
class Actions
  @myApp

  def initialize(myApp)
    @myApp = myApp
  end

  def doLogin(username, password)
    @myApp.app do
      if username == "Schwad" and password == "******"
        alert "Successful Login"
        caption link("Continue\n", :click => "/index"), align: "center"
      else
        alert "Incorrect username or password"
      end
    end
  end


end
class SuperLeg < Shoes
  url '/',  :index #make this login later
  url '/index',     :index
  url '/enter', :enter
  url '/view', :view

  def login
    stack do
      @myActions = Actions.new(self)
      username = edit_line
      password = edit_line :secret => true
      button "Login" do
          @myActions.doLogin(username.text, password.text)
      end
    end
  end

 # def enter
 #   flow(width: 800, background: "lightsteelblue") do
  #    stack width: 800 do
  #      banner "Welcome to Superleg!\n\n", align: "center"
  #    end
   #   stack width: 400 do
    #    caption link("Tasks to do\n", :click => "/view"), align: "left"
  #    end
   #   stack width: 400 do
    #    caption link("Add tasks\n", :click => "/enter"), align: "right"
#      end
 #   end
 # end

  def index
    flow do
      stack width: 645 do
        para "title"
        para "sample entry: '<name> on <date>; John Smith on Tuesday'.", align: "right"
        stack do
          para (link("New Task.", :click => "/"))
        end
        stack do
          @edit = edit_line :width => 0.7
        end
        flow do
            para "Set Task Type"
            list_box items: ["Call", "Email", "Bill"],
            width: 120, choose: "Call" do |list|
              @task.text = list.text
            end
           @task = para "No task selected"

            para "Set Priority"
            list_box items: ["1", "2", "3", "4"],
            width: 120, choose: "1" do |list|
              @priority.text = list.text
            end
           @priority = para "No priority selected"
        end

        button "Add" do
           if confirm("Add #{@edit.text}?")
            such_length = File.open("thelist.csv").readlines.size
            line_input = @edit.text
            @edit = ""
            para "added #{line_input}!"
            time = Time.new

            if @task.text == "Call"
              #line_input.split(//)[0..3].join('') == "call" #old checker
               CSV.open("thelist.csv", "ab") do |csv|
                csv << [such_length,"call", line_input, "#{time.hour}:#{time.min} #{time.day}/#{time.month}", @priority.text ]
              end

            elsif @task.text == "Email"
               CSV.open("thelist.csv", "ab") do |csv|
                csv << [such_length,"email", line_input, "#{time.hour}:#{time.min} #{time.day}/#{time.month}", @priority.text ]
              end

            elsif @task.text == "Bill"
               CSV.open("thelist.csv", "ab") do |csv|
                csv << [such_length,"bill", line_input, "#{time.hour}:#{time.min} #{time.day}/#{time.month}", @priority.text ]
              end
            end
          end
        end
        para "\n"
        para "Type in the 'number' of the task, and press delete to remove.", align: "right"
        flow do
          para "Delete Task    "
          @delete = edit_line :width => 0.1
          button "Delete" do
            if confirm("Delete task number #{@delete.text}?")
             #such_id = @delete.text
             # @delete = ""
              time = Time.new
              timefile ="#{time.hour}:#{time.min}, #{time.day}/#{time.month}"

              #copy the file #this bit works.
              i = 0

              CSV.foreach("thelist.csv") do |csvbig|
                if i == @delete.text.to_i
                    csvbig << timefile
                    CSV.open("removed.csv", "ab") do |csv|
                      csv << csvbig
                    end
                  para "\nTask #{i} removed!"
                end
                i += 1
              end
              #delete the file
              para arr_of_arrs
              CSV.read("thelist.csv", "w") do |what|
                what = arr_of_arrs
              end

              #f = File::open("thelist.csv", "r")
              #dest=File::open("data1.csv", "w")
              #f.each_line do |line|
              #  next if f.lineno == @delete.text.to_i
              #  dest.write(line)
              #end
              #f.close
              #dest.close
              #FileUtils.cp("data1.csv", "thelist.csv")
            end
          end
        end
      end
      ####################
      stack width: 600 do
        para "Show Tasks", align: "center"
        flow do
          button "Calls" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[1] == "call"
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
          button "Emails" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[1] == "email"
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
          button "Bills" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[1] == "bill"
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
          button "All" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if i == 0
                i += 1
                next
              end
              para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              i += 1
            end
          end
        end
        flow do
          button "Top Priority" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[4] == "1"
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
          button "2nd Priority" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[4] == "2"
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
          button "3rd Priority" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[4] == "3"
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
          button "Lowest Priority" do
            i = 0
            CSV.foreach("thelist.csv") do |row|
              if row[4].to_i > 3
                para "#{i}. #{row[1]} #{row[2]}, added #{row[3]}, priority level #{row[4]}.\n", :margin_left => 645
              end
              i += 1
            end
          end
        end
        caption link("Clear\n\n", :click => "/index")
      end
    end
  end
end


Shoes.app title: "SuperLegislator 0.0.1 Beta", :width => 1300, :height => 670
