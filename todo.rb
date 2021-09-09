require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

helpers do 
  # Return an error message if the name is invalid. Return nil if name is valid.
  def error_for_list_name(name)
    if !(1..100).cover? name.size
      "List name must be between 1 and 100 characters."
    elsif session[:lists].any? { |list| list[:name] == name }
      "List name must be unique."
    end
  end
  
  
  # Return an error message if the name is invalid. Return nil if name is valid.
  def error_for_todo(name)
    if !(1..100).cover? name.size
      "Todo must be between 1 and 100 characters."
    end
  end
  
  def class_value(completed)
    completed == "true" ? "complete" : ""
  end
  
  def all_completed(todos)
    if todos.all? {|todo| todo[:completed] == "true" } && !todos.empty?
      "complete"
    end
  end
  
  def not_complete(todos)
    todos.count { |todo| todo[:completed] == "false" }
  end
  
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| all_completed(list[:todos]) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
  
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] == "true" }
    
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Display a single todo list
get "/lists/:list_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  erb :single_list, layout: :layout
end

# Edit an exisiting list
get "/lists/:list_id/edit" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# Rename an existing list
post "/lists/:list_id/edit" do 
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  new_name = params[:new_name].strip
  error = error_for_list_name(new_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    session[:lists][@list_id][:name] = new_name
    session[:success] = "Your list name has been updated."
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing list
post "/lists/:list_id/delete" do
  @list_id = params[:list_id].to_i
  deleted_list = session[:lists].delete_at(@list_id)
  session[:success] = "The #{deleted_list[:name]} list has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :single_list, layout: :layout
  else
    @list[:todos] << { name: text, completed: "false" }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing todo
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @todo_id = params[:todo_id].to_i
  
  deleted_todo = @list[:todos].delete_at(@todo_id)
  session[:success] = "The #{deleted_todo[:name]} todo has been deleted."
  redirect "/lists/#{@list_id}"
end

def toggle(value)
  value == "true" ? "false" : "true"
end

# Toggle todo as complete
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @todo_id = params[:todo_id].to_i
  @list = session[:lists][@list_id]
  @todo_item = @list[:todos][@todo_id]
  @todo_item[:completed] = toggle(params[:completed])
  
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todos as complete
post "/lists/:list_id/all_completed" do
  @list_id = params[:list_id].to_i
  todos = session[:lists][@list_id][:todos]
  
  todos.each { |todo| todo[:completed] = "true" }
  
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end
