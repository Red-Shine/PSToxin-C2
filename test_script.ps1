Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$form = [Windows.Forms.Form]::new()
$form.Text = "PowerShell WinForms Demo"
$form.Size = [Drawing.Size]::new(400,200)
$form.StartPosition = "CenterScreen"
$label = [Windows.Forms.Label]::new()
$label.Location = [Drawing.Point]::new(20,20)
$label.Size = [Drawing.Size]::new(100,20)
$label.Text = "Enter your name:"
$form.Controls.Add($label)
$textBox = [Windows.Forms.TextBox]::new()
$textBox.Location = [Drawing.Point]::new(20,50)
$textBox.Size = [Drawing.Size]::new(250,20)
$form.Controls.Add($textBox)
$button = [Windows.Forms.Button]::new()
$button.Location = [Drawing.Point]::new(20,90)
$button.Size = [Drawing.Size]::new(100,30)
$button.Text = "Submit"
$button.Add_Click({[Windows.Forms.MessageBox]::Show("Hello, $($textBox.Text)!","Greeting","OK","Information")})
$form.Controls.Add($button)
$null = $form.ShowDialog()