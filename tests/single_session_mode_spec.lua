---@diagnostic disable: undefined-field
local TL = require "tests/test_lib"

describe("single_session_mode", function()
  local as = require "auto-session"
  local lib = require "auto-session.lib"

  TL.clearSessionFilesAndBuffers()

  it("uses locked session when enabled", function()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup {
      single_session_mode = true,
      log_level = "debug",
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created for the locked session
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Change directory to a subdirectory
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session again
    vim.cmd "e other.txt"
    as.SaveSession()

    -- The session should still be saved to the original locked session,
    -- not the new cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- There should NOT be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))

    vim.cmd("cd " .. original_cwd)
  end)

  TL.clearSessionFilesAndBuffers()

  it("uses current cwd when disabled", function()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup {
      single_session_mode = false,
      log_level = "debug",
    }

    -- Verify no session exists initially
    assert.equals(0, vim.fn.filereadable(TL.default_session_path))

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created for the current cwd
    assert.equals(1, vim.fn.filereadable(TL.default_session_path))

    -- Change directory to a subdirectory
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)

    -- Create another file and save session
    vim.cmd "e other.txt"
    as.SaveSession()

    -- This time, there should be a session file for the new cwd
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(new_cwd_session_path))

    vim.fn.delete(new_cwd_session_path)

    vim.cmd("cd " .. original_cwd)
  end)

  it("updates locked session when restoring any session", function()
    -- First, create a session without the single_session_mode feature
    -- This simulates a session created before the feature was added

    -- Setup without single_session_mode first
    require("auto-session").setup {
      single_session_mode = false,
      log_level = "debug",
    }

    local original_cwd = vim.fn.getcwd()

    -- Change to tests directory and create a session there
    vim.cmd "cd tests"
    local tests_cwd = vim.fn.getcwd()

    -- Create a test file and save session
    vim.cmd "e test.txt"
    as.SaveSession()

    -- Verify the session was created
    local session_path = TL.session_dir .. lib.escape_session_name(tests_cwd) .. ".vim"
    assert.equals(1, vim.fn.filereadable(session_path))

    -- Go back to original directory
    vim.cmd("cd " .. original_cwd)

    -- Now enable single_session_mode and setup again
    require("auto-session").setup {
      single_session_mode = true,
      log_level = "debug",
    }

    -- Verify locked_session_name is set to original directory
    assert.equals(original_cwd, as.locked_session_name)

    -- Now restore the session from tests directory
    assert.True(as.RestoreSession(tests_cwd))

    -- After restoring the session, locked_session_name should be updated
    -- to match the restored session's directory
    assert.equals(tests_cwd, as.locked_session_name)

    vim.cmd("cd " .. original_cwd)
    vim.fn.delete(session_path)
  end)

  it("handles git branch sessions correctly when extracting directory", function()
    local original_cwd = vim.fn.getcwd()

    require("auto-session").setup {
      single_session_mode = true,
      git_use_branch_name = true,
      log_level = "debug",
    }

    -- Create a mock session name with git branch format: "/path/to/dir|main"
    local session_name_with_branch = original_cwd .. "|main"
    local session_path = TL.session_dir .. lib.escape_session_name(session_name_with_branch) .. ".vim"

    -- Create a minimal session file
    vim.fn.writefile({ '" Session file' }, session_path)

    -- Set locked_session_name to something different initially
    as.locked_session_name = "/different/path"

    -- Restore the session with git branch
    assert.True(as.RestoreSession(session_name_with_branch))

    -- locked_session_name should be updated to the directory part (without the git branch)
    assert.equals(original_cwd, as.locked_session_name)

    vim.fn.delete(session_path)
  end)

  it("disables single_session_mode when cwd_change_handling is also enabled", function()
    local config = require "auto-session.config"

    require("auto-session").setup {
      single_session_mode = true,
      cwd_change_handling = true,
      log_level = "debug",
    }

    -- The config validation should have disabled single_session_mode
    assert.False(config.single_session_mode)
    assert.True(config.cwd_change_handling)

    -- locked_session_name should not be set since single_session_mode was disabled
    assert.equals(nil, as.locked_session_name)
  end)

  it("maintains single session mode without extra metadata", function()
    TL.clearSessionFilesAndBuffers()
    
    local original_cwd = vim.fn.getcwd()
    
    as.locked_session_name = nil
    local config = require "auto-session.config"
    config.single_session_mode = nil
    
    require("auto-session").setup {
      single_session_mode = true,
      log_level = "debug",
    }

    -- Verify locked_session_name is set (should be the current working directory at setup time)
    assert.is_not_nil(as.locked_session_name)
    assert.True(type(as.locked_session_name) == "string")
    assert.True(string.len(as.locked_session_name) > 0)

    -- Create a test file and save session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession()

    -- Verify session was created (check for session file based on locked session name)
    local lib = require "auto-session.lib"
    local expected_session_path = TL.session_dir .. lib.escape_session_name(as.locked_session_name) .. ".vim"
    assert.equals(1, vim.fn.filereadable(expected_session_path))

    -- Verify that session persistence is maintained through manually_named_session
    assert.True(as.manually_named_session, "manually_named_session should be true when single_session_mode is enabled")
    
    -- Change directory and save again - should save to same session
    vim.cmd "cd tests"
    local new_cwd = vim.fn.getcwd()
    assert.True(new_cwd ~= original_cwd)
    
    vim.cmd "e test2.txt"
    as.SaveSession()
    
    -- Should still save to the original session, not create a new one for new_cwd
    assert.equals(1, vim.fn.filereadable(expected_session_path))
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path), "Should not create session for new cwd")
    
    vim.cmd("cd " .. original_cwd)
  end)

  it("works with manually named sessions", function()
    TL.clearSessionFilesAndBuffers()
    
    local original_cwd = vim.fn.getcwd()
    
    require("auto-session").setup {
      single_session_mode = true,
      log_level = "debug",
    }

    -- Create a manually named session
    vim.cmd("e " .. TL.test_file)
    as.SaveSession("my_project")

    -- Verify the named session was created
    local named_session_path = TL.session_dir .. lib.escape_session_name("my_project") .. ".vim"
    assert.equals(1, vim.fn.filereadable(named_session_path))
    
    -- Verify locked_session_name is updated to the manually named session
    assert.equals("my_project", as.locked_session_name)

    -- Change directory and save again - should still save to the named session
    vim.cmd "cd tests"
    vim.cmd "e test2.txt"
    as.SaveSession()
    
    -- Should still save to the named session
    assert.equals(1, vim.fn.filereadable(named_session_path))
    
    -- Should not create a session for the new cwd
    local new_cwd = vim.fn.getcwd()
    local new_cwd_session_path = TL.session_dir .. lib.escape_session_name(new_cwd) .. ".vim"
    assert.equals(0, vim.fn.filereadable(new_cwd_session_path))
    
    vim.fn.delete(named_session_path)
    vim.cmd("cd " .. original_cwd)
  end)

  TL.clearSessionFilesAndBuffers()
end)