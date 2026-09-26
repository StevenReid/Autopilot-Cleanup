function Show-DeviceSelectionGrid {
    param (
        [Parameter(Mandatory)]
        [array]$Devices,
        [string]$Title = "Select Devices to Remove from All Services"
    )

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Convert a date value (DateTime, ISO string or "null") to a DateTime for sorting; missing dates sort first
    $toSortDate = {
        param($value)
        $parsed = [datetime]::MinValue
        if ($value -is [datetime]) { $value }
        elseif ($value -and [datetime]::TryParse([string]$value, [ref]$parsed)) { $parsed }
        else { [datetime]::MinValue }
    }

    # Display a sort date in local time using the regional short date format, or "null" when there is no date
    $toDisplayDate = {
        param([datetime]$date)
        if ($date -eq [datetime]::MinValue) { return "null" }
        if ($date.Kind -eq [System.DateTimeKind]::Utc) { $date = $date.ToLocalTime() }
        $date.ToString("d", [System.Globalization.CultureInfo]::CurrentCulture)
    }

    # Store devices with selection state
    $script:deviceList = [System.Collections.ArrayList]::new()
    foreach ($device in $Devices) {
        $registeredSort = & $toSortDate $device.EntraRegistered
        $lastActivitySort = & $toSortDate $device.EntraLastActivity
        $null = $script:deviceList.Add([PSCustomObject]@{
            Selected     = $false
            DisplayName  = $device.DisplayName
            SerialNumber = $device.SerialNumber
            Model        = $device.Model
            GroupTag     = $device.GroupTag
            AutopilotFound = $device.AutopilotFound
            IntuneFound  = $device.IntuneFound
            EntraFound   = $device.EntraFound
            IntuneName   = $device.IntuneName
            EntraName    = $device.EntraName
            EntraRegistered   = & $toDisplayDate $registeredSort
            EntraLastActivity = & $toDisplayDate $lastActivitySort
            EntraRegisteredSort   = $registeredSort
            EntraLastActivitySort = $lastActivitySort
            EntraOwner            = $device.EntraOwner
            AutopilotAssignedUser = $device.AutopilotAssignedUser
            Original   = $device
        })
    }

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$Title" Height="700" Width="1800" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBox Name="SearchBox" Grid.Row="0" Margin="0,0,0,10" Padding="5" FontSize="14"/>
        <TextBlock Grid.Row="0" Margin="5,5,0,0" Foreground="Gray" IsHitTestVisible="False" Name="SearchPlaceholder">Search devices...</TextBlock>

        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="SelectAllBtn" Content="Select All" Padding="10,5" Margin="0,0,10,0"/>
            <Button Name="ClearAllBtn" Content="Clear All" Padding="10,5" Margin="0,0,10,0"/>
            <TextBlock Name="CountLabel" VerticalAlignment="Center" Foreground="Gray" FontSize="14"/>
        </StackPanel>

        <ListView Name="DeviceList" Grid.Row="2" SelectionMode="Multiple"
                  VirtualizingStackPanel.IsVirtualizing="True"
                  VirtualizingStackPanel.VirtualizationMode="Recycling"
                  ScrollViewer.IsDeferredScrollingEnabled="True"
                  ScrollViewer.CanContentScroll="True">
            <ListView.View>
                <GridView>
                    <GridViewColumn Width="40">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <CheckBox IsChecked="{Binding Selected, Mode=TwoWay}" Margin="5,0,0,0"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Display Name" Width="180" DisplayMemberBinding="{Binding DisplayName}"/>
                    <GridViewColumn Header="Serial Number" Width="220" DisplayMemberBinding="{Binding SerialNumber}"/>
                    <GridViewColumn Header="Model" Width="120" DisplayMemberBinding="{Binding Model}"/>
                    <GridViewColumn Header="Group Tag" Width="80" DisplayMemberBinding="{Binding GroupTag}"/>
                    <GridViewColumn Header="Autopilot" Width="70" DisplayMemberBinding="{Binding AutopilotFound}"/>
                    <GridViewColumn Header="Intune" Width="60" DisplayMemberBinding="{Binding IntuneFound}"/>
                    <GridViewColumn Header="Entra" Width="60" DisplayMemberBinding="{Binding EntraFound}"/>
                    <GridViewColumn Header="Intune Name" Width="150" DisplayMemberBinding="{Binding IntuneName}"/>
                    <GridViewColumn Header="Entra Name" Width="150" DisplayMemberBinding="{Binding EntraName}"/>
                    <GridViewColumn Header="Entra Registered" Width="120" DisplayMemberBinding="{Binding EntraRegistered}"/>
                    <GridViewColumn Header="Entra Last Activity" Width="120" DisplayMemberBinding="{Binding EntraLastActivity}"/>
                    <GridViewColumn Header="Entra Owner" Width="200" DisplayMemberBinding="{Binding EntraOwner}"/>
                    <GridViewColumn Header="Autopilot Assigned User" Width="200" DisplayMemberBinding="{Binding AutopilotAssignedUser}"/>
                </GridView>
            </ListView.View>
        </ListView>

        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="OkBtn" Content="OK" Width="100" Padding="5" Margin="0,0,10,0" IsDefault="True" FontSize="14"/>
            <Button Name="CancelBtn" Content="Cancel" Width="100" Padding="5" IsCancel="True" FontSize="14"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    $searchBox = $window.FindName("SearchBox")
    $searchPlaceholder = $window.FindName("SearchPlaceholder")
    $selectAllBtn = $window.FindName("SelectAllBtn")
    $clearAllBtn = $window.FindName("ClearAllBtn")
    $countLabel = $window.FindName("CountLabel")
    $listView = $window.FindName("DeviceList")
    $okBtn = $window.FindName("OkBtn")
    $cancelBtn = $window.FindName("CancelBtn")

    # Use CollectionViewSource for filtered view instead of rebuilding lists
    $listView.ItemsSource = $script:deviceList
    $script:collectionView = [System.Windows.Data.CollectionViewSource]::GetDefaultView($script:deviceList)
    $countLabel.Text = "0 of $($script:deviceList.Count) selected"

    # Current search text for filter
    $script:currentSearch = ""

    # Set filter predicate on the collection view
    $script:collectionView.Filter = [System.Predicate[object]]{
        param($item)
        if ([string]::IsNullOrEmpty($script:currentSearch)) { return $true }
        $s = $script:currentSearch
        return (
            ($item.DisplayName -and $item.DisplayName.ToLower().Contains($s)) -or
            ($item.SerialNumber -and $item.SerialNumber.ToLower().Contains($s)) -or
            ($item.Model -and $item.Model.ToLower().Contains($s)) -or
            ($item.GroupTag -and $item.GroupTag.ToLower().Contains($s))
        )
    }

    # Update count function
    $updateCount = {
        $selected = ($script:deviceList | Where-Object { $_.Selected }).Count
        $countLabel.Text = "$selected of $($script:deviceList.Count) selected"
    }

    # Debounce timer for search - waits 300ms after last keystroke before filtering
    $script:searchTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:searchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:searchTimer.Add_Tick({
        $script:searchTimer.Stop()
        $script:currentSearch = $searchBox.Text.ToLower()
        $script:collectionView.Refresh()
    })

    $searchBox.Add_TextChanged({
        $searchPlaceholder.Visibility = if ($searchBox.Text) { "Collapsed" } else { "Visible" }
        $script:searchTimer.Stop()
        $script:searchTimer.Start()
    })

    $selectAllBtn.Add_Click({
        # Only select visible (filtered) items
        foreach ($item in $script:collectionView) { $item.Selected = $true }
        $listView.Items.Refresh()
        & $updateCount
    })

    $clearAllBtn.Add_Click({
        foreach ($item in $script:collectionView) { $item.Selected = $false }
        $listView.Items.Refresh()
        & $updateCount
    })

    # Update count when checkbox changes
    $listView.AddHandler(
        [System.Windows.Controls.CheckBox]::CheckedEvent,
        [System.Windows.RoutedEventHandler]{ & $updateCount }
    )
    $listView.AddHandler(
        [System.Windows.Controls.CheckBox]::UncheckedEvent,
        [System.Windows.RoutedEventHandler]{ & $updateCount }
    )

    # Sort by clicking column headers - click again to reverse direction
    $sortKeyMap = @{
        EntraRegistered   = "EntraRegisteredSort"
        EntraLastActivity = "EntraLastActivitySort"
    }
    $script:sortedHeader = $null
    $script:sortedHeaderText = $null
    $script:sortProperty = $null
    $script:sortDirection = [System.ComponentModel.ListSortDirection]::Ascending

    $listView.AddHandler(
        [System.Windows.Controls.GridViewColumnHeader]::ClickEvent,
        [System.Windows.RoutedEventHandler]{
            param($src, $e)
            $header = $e.OriginalSource
            # Ignore the checkbox column and the empty filler header
            if ($header -isnot [System.Windows.Controls.GridViewColumnHeader] -or -not $header.Column) { return }
            $binding = $header.Column.DisplayMemberBinding
            if (-not $binding) { return }

            $property = $binding.Path.Path
            if ($sortKeyMap.ContainsKey($property)) { $property = $sortKeyMap[$property] }

            if ($script:sortProperty -eq $property) {
                $script:sortDirection = if ($script:sortDirection -eq [System.ComponentModel.ListSortDirection]::Ascending) {
                    [System.ComponentModel.ListSortDirection]::Descending
                } else {
                    [System.ComponentModel.ListSortDirection]::Ascending
                }
            } else {
                $script:sortDirection = [System.ComponentModel.ListSortDirection]::Ascending
            }
            $script:sortProperty = $property

            $script:collectionView.SortDescriptions.Clear()
            $script:collectionView.SortDescriptions.Add([System.ComponentModel.SortDescription]::new($property, $script:sortDirection))

            # Move the sort arrow to the clicked header
            if ($script:sortedHeader) { $script:sortedHeader.Column.Header = $script:sortedHeaderText }
            if ($script:sortedHeader -ne $header) { $script:sortedHeaderText = [string]$header.Column.Header }
            $arrow = if ($script:sortDirection -eq [System.ComponentModel.ListSortDirection]::Ascending) { [char]0x25B2 } else { [char]0x25BC }
            $header.Column.Header = "$($script:sortedHeaderText) $arrow"
            $script:sortedHeader = $header
        }
    )

    $script:dialogResult = $false
    $okBtn.Add_Click({
        $script:dialogResult = $true
        $window.Close()
    })

    $cancelBtn.Add_Click({
        $script:dialogResult = $false
        $window.Close()
    })

    $null = $window.ShowDialog()

    if ($script:dialogResult) {
        return ($script:deviceList | Where-Object { $_.Selected } | ForEach-Object { $_.Original })
    }
    return $null
}
