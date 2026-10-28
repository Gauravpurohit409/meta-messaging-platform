module ApplicationHelper
  def field_class
    "mt-1 w-full rounded-xl border border-[#e4dccf] bg-white px-3 py-2.5 text-[15px] text-[#1c1915] outline-none ring-[#1f7a45] placeholder:text-[#a39b90] focus:ring-2"
  end

  def label_class
    "block text-sm font-medium text-[#3d3832]"
  end

  def btn_primary
    "inline-flex items-center justify-center rounded-full bg-[#1f7a45] px-4 py-2.5 text-sm font-medium text-white transition hover:bg-[#186339] disabled:opacity-60"
  end

  def btn_secondary
    "inline-flex items-center justify-center rounded-full bg-white px-4 py-2.5 text-sm font-medium text-[#1c1915] ring-1 ring-[#e4dccf] transition hover:bg-[#faf7f2]"
  end

  def btn_danger
    "inline-flex items-center justify-center rounded-full bg-white px-4 py-2.5 text-sm font-medium text-[#9f2d2d] ring-1 ring-[#f0c9c2] transition hover:bg-[#fff5f2]"
  end

  def nav_class(path)
    active = request.path == path || (path != dashboard_path && request.path.start_with?(path))
    base = "flex items-center rounded-xl px-3 py-2 text-sm font-medium"
    if active
      "#{base} bg-[#1f7a45] text-white"
    else
      "#{base} text-[#e7efe8] hover:bg-white/10"
    end
  end

  def status_pill(status)
    palette = {
      "draft" => "bg-[#efe8da] text-[#5c5348]",
      "pending" => "bg-[#f8edd4] text-[#8a5a10]",
      "approved" => "bg-[#e5f4ea] text-[#17693a]",
      "rejected" => "bg-[#fde8e4] text-[#9f2d2d]",
      "paused" => "bg-[#f8edd4] text-[#8a5a10]",
      "disabled" => "bg-[#fde8e4] text-[#9f2d2d]",
      "flagged" => "bg-[#f8edd4] text-[#8a5a10]",
      "archived" => "bg-[#efe8da] text-[#5c5348]",
      "running" => "bg-[#e7f0ea] text-[#1e4d34]",
      "scheduled" => "bg-[#f8edd4] text-[#8a5a10]",
      "completed" => "bg-[#e5f4ea] text-[#17693a]",
      "failed" => "bg-[#fde8e4] text-[#9f2d2d]",
      "sent" => "bg-[#e7eef8] text-[#1e3a5f]",
      "delivered" => "bg-[#e5f4ea] text-[#17693a]",
      "read" => "bg-[#e3f6ea] text-[#0f5132]",
      "queued" => "bg-[#efe8da] text-[#5c5348]",
      "pending_recipient" => "bg-[#efe8da] text-[#5c5348]"
    }
    classes = palette.fetch(status.to_s, "bg-[#efe8da] text-[#5c5348]")
    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium #{classes}")
  end

  def stamp(time)
    return "—" if time.blank?

    zone = time.in_time_zone.strftime("%Z")
    "#{time.in_time_zone.strftime("%-d %b %Y, %-I:%M %p")} #{zone}"
  end

  def greeting
    hour = Time.zone.now.hour
    if hour < 12
      "Good morning"
    elsif hour < 17
      "Good afternoon"
    else
      "Good evening"
    end
  end

  def fill_variables(text, examples, prefix)
    text.to_s.gsub(/\{\{(\d+)\}\}/) do
      examples["#{prefix}_#{$1}"].presence || "{{#{$1}}}"
    end
  end
end
