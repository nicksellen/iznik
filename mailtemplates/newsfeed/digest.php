<?php
require_once(IZNIK_BASE . '/mailtemplates/header.php');
require_once(IZNIK_BASE . '/mailtemplates/footer.php');

function notification_digest($url, $off, $toname, $to, $summ) {
    $siteurl = "https://" . USER_SITE;
    $setting = $siteurl . '/settings';
    $sitename = SITE_NAME;
    $logo = USERLOGO;

    $html = <<<EOT
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <title>New Notifications</title>
EOT;

    $html .= mail_header();
    $html .= <<<EOT
<!-- Start Background -->
<table width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F7F5EB">
    <tr>
        <td width="100%" valign="top" align="center">

            <!-- Start Wrapper  -->
            <table width="95%" cellpadding="0" cellspacing="0" border="0" class="wrapper" bgcolor="#FFFFFF">
                <tr>
                    <td height="10" style="font-size:10px; line-height:10px;">   </td><!-- Spacer -->
                </tr>
                <tr>
                    <td align="center">

                        <!-- Start Container  -->
                        <table width="100%" cellpadding="0" cellspacing="0" border="0" class="container">
                            <tr>
                                <td width="100%" class="mobile" style="font-family:arial; font-size:12px; line-height:18px;">
                                    <table width="95%" cellpadding="0" cellspacing="0" border="0" class="wrapper" bgcolor="#FFFFFF">
                                        <tr>
                                            <td height="20" style="font-size:10px; line-height:10px;"> </td><!-- Spacer -->
                                        </tr>
                                        <tr>
                                            <td align="center">
                                                <table width="95%" cellpadding="0" cellspacing="0" border="0" class="container">
                                                    <tbody>
                                                        <tr>
                                                            <td width="150" class="mobileOff">
                                                                <table class="button" width="90%" cellpadding="0" cellspacing="0" align="left" border="0">
                                                                    <tr>
                                                                        <td>                                                           
                                                                            <a href="$siteurl">
                                                                                <img src="$logo" width="100" height="100" style="border-radius:3px; margin:0; padding:0; border:none; display:block;" alt="" class="imgClass" />
                                                                            </a>
                                                                        </td>
                                                                    </tr>
                                                                </table>               
                                                            </td>    
                                                            <td class="mobile" align="left" valign="top">
                                                                <p>Dear $toname,</p>
                                                                <p>Now you can chat to nearby freeglers! This is a new feature - if you don't want these emails, turn them off by mailing <a href="mailto:$off">$off</a>
                                                                <p>Here are some recent topics from freeglers near you:</p>
                                                                <p>$summ</p>
                                                                <p>(If these aren't nearby, please check your postcode in <a href="$setting">Settings</a>)</p>
                                                                <table class="button" width="90%" cellpadding="0" cellspacing="0" align="left" border="0">
                                                                    <tr>
                                                                        <td width="50%" height="36" bgcolor="#377615" align="center" valign="middle"
                                                                            style="font-family: Century Gothic, Arial, sans-serif; font-size: 16px; color: #ffffff;
                                                                                line-height:18px; border-radius:3px;">
                                                                            <a href="$url" alias="" style="font-family: Century Gothic, Arial, sans-serif; text-decoration: none; color: #ffffff;">&nbsp;Join&nbsp;the&nbsp;conversation!</a>
                                                                        </td>
                                                                    </tr>
                                                                </table> 
                                                            </td>
                                                        </tr>        
                                                        <tr>
                                                            <td height="20" style="font-size:10px; line-height:10px;"> </td><!-- Spacer -->
                                                        </tr>
                                                        <tr>
                                                            <td colspan="2">
                                                                <font color=gray><hr></font>
                                                            </td>
                                                        </tr>        
                                                        <tr>
                                                        </tr>
                                                        <tr>
                                                            <td colspan="2" style="color: grey; font-size:10px;">
                                                                <p>You've received this automated mail because $to is a member of <a href="$siteurl">$sitename</a>.  You can turn these notification mails off from <a href="$siteurl/settings">here</a> or by emailing <a href="mailto:$off">$off</a></p>                                                            
                                                                <p>Freegle is registered as a charity with HMRC (ref. XT32865) and is run by volunteers. Which is nice.</p> 
                                                            </td>
                                                        </tr>        
                                                    </tbody>
                                                </table>
                                            </td>
                                        </tr>
                                    </table>
                                </td>
                            </tr>
                        </table>
                    </td>
                </tr>
                <tr>
                    <td height="10" style="font-size:10px; line-height:10px;"> </td>
                </tr>
           </table>
       </td>
       </tr>
</table>

</body>
</html>
EOT;

    return($html);
}