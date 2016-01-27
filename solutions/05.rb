require "time"
require 'digest/sha1'

class RepoResult
  attr_accessor :message, :result
  def initialize(message, status = false, result = nil)
    @message = message
    @status = status
    @result = result
  end

  def success?
    @status
  end

  def error?
    not @status
  end
end

class Commit
  attr_accessor :objects_hash, :message, :date, :hash
  def initialize(old_objects, new_objects, deleted_objects,  message)
    @message = message
    @date = Time.new
    hash_string = @date.strftime("%a %b %d %H:%M %Y %z") + message
    @hash =  Digest::SHA1.hexdigest(hash_string)
    @objects_hash = old_objects.dup
    new_objects.each { |key, value| @objects_hash[key] = value }
    deleted_objects.each { |key| @objects_hash.delete(key) }
  end

  def date_formated
    @date.strftime("%a %b %d %H:%M %Y %z")
  end

  def objects
    @objects_hash.values
  end
end

class Branch
  attr_accessor :commits, :new_changes, :name
  def initialize(name, inherited_commits)
    @commits = inherited_commits.dup
    @name = name
    @new_changes = {}
    @deleted_objects = []
  end

  def add(name, object)
    @new_changes[name] = object
  end

  def commit(message)
    last_commit = @commits[-1]
    state = last_commit != nil ? last_commit.objects_hash : {}
    new_commit = Commit.new state, @new_changes, @deleted_objects, message
    @commits << new_commit
    size = @new_changes.size + @deleted_objects.size
    @new_changes, @deleted_objects = {}, []
    size
  end

  def remove(name)
    @deleted_objects << name if @commits[-1].objects_hash[name] != nil
    @commits[-1].objects_hash[name]
  end

  def get(name)
    return nil if @commits.size == 0
    commited_objects = @commits[-1].objects_hash
    commited_objects[name]
  end

  def checkout(hash)
    commit = @commits.select { |commit| commit.hash == hash }.first
    return nil if commit == nil
    index = @commits.find_index(commit)
    remove_commits_count = @commits.size - index - 1
    @commits.pop remove_commits_count
    commit
  end
end

class BranchManager
  def initialize(store)
    @store = store
  end

  def create(name)
    branches = @store.branches
    store_head = @store.head_branch
    if branches[name] != nil
      return RepoResult.new("Branch #{name} already exists.", false, nil)
    end
    new_branch = Branch.new name, branches[store_head].commits
    branches[name] = new_branch
    RepoResult.new("Created branch #{name}.", true, nil)
  end

  def checkout(branch_name)
    branches = @store.branches
    if branches[branch_name] == nil
      return RepoResult.new("Branch #{branch_name} does not exist.", false, nil)
    end
    @store.head_branch = branch_name
    RepoResult.new("Switched to branch #{branch_name}.", true, nil)
  end

  def remove(branch_name)
    branches = @store.branches
    if @store.head_branch == branch_name
      return RepoResult.new("Cannot remove current branch.", false, nil)
    elsif branches[branch_name] == nil
      return RepoResult.new("Branch #{branch_name} does not exist.", false, nil)
    end
    branches.delete(branch_name)
    RepoResult.new("Removed branch #{branch_name}.", true, nil)
  end

  def list
    branches = @store.branches
    head = @store.head_branch
    format = -> (name) do
      name == @store.branches[head].name ? ("* " + name) : ("  " + name)
    end
    names = branches.map { |name, branch| name }.sort
    message = names.map { |name| format.call name }.join("\n")
    RepoResult.new(message, true, nil)
  end
end

class ObjectStore
  attr_accessor :branches, :head_branch
  def initialize
    master = Branch.new "master", []
    @branches = {}
    @head_branch = "master"
    @branches[@head_branch] = master
  end

  def add(name, object)
    @branches[@head_branch].add name, object
    message = "Added #{name} to stage."
    RepoResult.new(message, true, object)
  end

  def commit(message)
    count = @branches[@head_branch].commit message
    if count > 0
      commit = @branches[@head_branch].commits[-1]
      RepoResult.new("#{message}\n\t#{count} objects changed", true, commit)
    else
      RepoResult.new("Nothing to commit, working directory clean.")
    end
  end

  def remove(name)
    removed_object = @branches[@head_branch].remove name
    if removed_object != nil
      RepoResult.new("Added #{name} for removal.", true, removed_object)
    else
      RepoResult.new("Object #{name} is not committed.", false, nil)
    end
  end

  def checkout(commit_hash)
    commit = @branches[@head_branch].checkout commit_hash
    if commit == nil
      RepoResult.new("Commit #{commit_hash} does not exist.")
    else
      RepoResult.new("HEAD is now at #{commit_hash}.", true, commit)
    end
  end

  def branch
    BranchManager.new self
  end

  def format_commit_log(commit)
    format = -> (commit) do
      time = commit.date_formated
      "Commit #{commit.hash}\nDate: #{time}\n\n\t#{commit.message}"
    end
  end


  def log
    commits, name = branches[@head_branch].commits, @head_branch
    if commits.size == 0
      return RepoResult.new("Branch #{name} does not have any commits yet.")
    end
    format =  format_commit_log(commits)
    message = commits.reverse.map { |commit| format.call commit }.join("\n\n")
    RepoResult.new(message, true)
  end

  def head
    commits, name = branches[@head_branch].commits, @head_branch
    if commits.size == 0
      return RepoResult.new("Branch #{name} does not have any commits yet.")
    end
    last_commit = commits[-1]
    RepoResult.new(last_commit.message, true, last_commit)
  end

  def get(name)
    needed_object = branches[@head_branch].get name
    if needed_object == nil
      RepoResult.new("Object #{name} is not committed.")
    else
      RepoResult.new("Found object #{name}.", true, needed_object)
    end
  end

  def self.init(&block)
    repo = ObjectStore.new
    if block_given?
      repo.instance_eval &block
    end
    repo
  end
end
