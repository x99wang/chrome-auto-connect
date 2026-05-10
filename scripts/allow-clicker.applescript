-- click_allow_detect.applescript
-- 单次检测 Chrome 弹窗并点击「允许」按钮
-- 返回: "clicked" | "no_sheet" | "no_chrome"
tell application "Google Chrome" to activate
delay 0.5
tell application "System Events"
	-- 检查 Chrome 是否运行
	if not (exists process "Google Chrome") then
		return "no_chrome"
	end if
	
	tell process "Google Chrome"
		set winCount to count of windows
		if winCount is 0 then
			return "no_sheet"
		end if
		
		repeat with wIdx from 1 to winCount
			set aWindow to window wIdx
			
			-- 检查该窗口是否有 sheet
			try
				set sheetCount to count of sheets of aWindow
			on error
				set sheetCount to 0
			end try
			
			if sheetCount > 0 then
				set targetSheet to sheet 1 of aWindow
				
				try
					set allElements to entire contents of targetSheet
					
					repeat with anElement in allElements
						set theRole to (role of anElement) as string
						
						if theRole is "AXButton" then
							try
								set theDesc to description of anElement as string
								
								if theDesc is "允许" then
									click anElement
									return "clicked"
								end if
							end try
						end if
					end repeat
				end try
			end if
		end repeat
	end tell
end tell
return "no_sheet"