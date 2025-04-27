# This script is meant to be run in the user context
# It will create a toast notification to inform the user that updates have been installed and prompt them to reboot or snooze the message.

try {
    # Define Toast Notification Content
    $Text1 = New-BTText -Content "Message from IT Department"
    $Text2 = New-BTText -Content "Updates have been installed on your computer. Please select if you'd like to reboot now, or snooze this message."

    # Define Buttons
    $Button = New-BTButton -Content "Snooze" -snooze -id 'SnoozeTime'
    $Button2 = New-BTButton -Content "Reboot now" -Arguments "ToastReboot:" -ActivationType Protocol

    # Define Snooze Selection Box Items
    $15Min = New-BTSelectionBoxItem -Id 15 -Content '15 minutes'
    $1Hour = New-BTSelectionBoxItem -Id 60 -Content '1 hour'
    $4Hour = New-BTSelectionBoxItem -Id 240 -Content '4 hours'
    $Items = $15Min, $1Hour, $4Hour

    # Define Snooze Selection Box
    $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 15 -Items $Items

    # Define Actions
    $Action = New-BTAction -Buttons $Button, $Button2 -inputs $SelectionBox

    # Define Binding and Visual
    $Binding = New-BTBinding -Children $Text1, $Text2
    $Visual = New-BTVisual -BindingGeneric $Binding

    # Define Content
    $Content = New-BTContent -Visual $Visual -Actions $Action -Scenario Reminder

    # Submit Notification
    Submit-BTNotification -Content $Content
}
catch {
    # Error handling
    Write-Error "Error creating/submitting toast notification: $($_.Exception.Message)"
}