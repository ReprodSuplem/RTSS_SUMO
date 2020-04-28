# coding: utf-8

import networkx as nx

import argparse
import itertools
import math
import progressbar
import re
import sys

import mysql.connector


################
##            ##
##    定数    ##
##            ##
################


RX = 6378137.0
RY = 6356752.31414
E2 = ((RX * RX) - (RY * RY)) / (RX * RX)


##########################
##                      ##
##    グローバル変数    ##
##                      ##
##########################


bounds = {}
headers = {}
highway_vals = []
oneway_vals = {}
nodes = {}
ways = {}


################
##            ##
##    関数    ##
##            ##
################


# コマンドライン引数を処理
def parse_args():
    usage = "python3 {} OSM [--degree DEGREE] [--meter METER]".format(__file__)
    argparser = argparse.ArgumentParser(usage = usage)
    argparser.add_argument("osm", nargs = 1)
    argparser.add_argument("--degree", type = int, default = 180, help = "Compression threshold")
    argparser.add_argument("--meter", type = int, default = 0, help = "Compression threshold")
    return argparser.parse_args()


# 保存するhighwayキーの値を設定
def set_highway_vals():
    global highway_vals

    #highway_vals.append("motorway")
    highway_vals.append("trunk")
    highway_vals.append("primary")
    highway_vals.append("secondary")
    highway_vals.append("tertiary")
    highway_vals.append("unclassified")
    highway_vals.append("residential")
    highway_vals.append("service")
    highway_vals.append("living_street")
    highway_vals.append("road")
    #highway_vals.append("motorway_link")
    highway_vals.append("trunk_link")
    highway_vals.append("primary_link")
    highway_vals.append("secondary_link")
    highway_vals.append("tertiary_link")


# 一方通行の値を設定
def set_oneway_vals():
    global oneway_vals

    oneway_vals["yes"] = ["yes", "true", "1"]
    oneway_vals["-1"] = ["-1", "reverse", "reversible", "alternating"]


# ヒュベニの公式を用いて直線距離を計算
def calc_hubeny(slat, slon, elat, elon):

    # 緯度経度のラジアン
    slat_r = slat * math.pi / 180
    slon_r = slon * math.pi / 180
    elat_r = elat * math.pi / 180
    elon_r = elon * math.pi / 180

    # 準備
    dx = slon_r - elon_r
    dy = slat_r - elat_r
    py = (slat_r + elat_r) / 2
    w = math.sqrt(1.0 - E2 * math.sin(py) * math.sin(py))
    n = RX / w
    m = RX * (1.0 - E2) / math.pow(w, 3)

    return math.sqrt(math.pow(dy * m, 2) + math.pow(dx * n * math.cos(py), 2))


# 文字列からタグ名を取得
def get_tag(text):
    match = re.search("<(.+?)( |>|/>)", text)
    return match.group(1)


# 文字列からOSMの範囲を取得
def get_bounds(text):
    match = re.search("minlat=(\"|')([0-9.-]+)(\"|') minlon=(\"|')([0-9.-]+)(\"|') maxlat=(\"|')([0-9.-]+)(\"|') maxlon=(\"|')([0-9.-]+)(\"|')", text)
    bounds["minlat"] = float(match.group(2))
    bounds["minlon"] = float(match.group(5))
    bounds["maxlat"] = float(match.group(8))
    bounds["maxlon"] = float(match.group(11))
    return bounds


# 文字列からidを取得
def get_id(text):
    return re.search("id=(\"|')(.+?)(\"|')", text).group(2)


# 文字列からactionを取得
def get_action(text):
    match = re.search("action=(\"|')(.+?)(\"|')", text)
    if (match is None):
        return ""
    elif match.group(2) == "delete":
        return None
    else:
        return match.group(2)


# 文字列からlatを取得
def get_lat(text):
    return float(re.search("lat=(\"|')([0-9.-]+)(\"|')", text).group(2))


# 文字列からlonを取得
def get_lon(text):
    return float(re.search("lon=(\"|')([0-9.-]+)(\"|')", text).group(2))


# 文字列からversionを取得
def get_version(text):
    if re.search("version=(\"|')([0-9]+)(\"|')", text) is None:
        return None
    else:
        return int(re.search("version=(\"|')([0-9]+)(\"|')", text).group(2))


# 文字列からrefを取得
def get_ref(text):
    return re.search("ref=(\"|')(.+?)(\"|')", text).group(2)


# 文字列からkとvを取得
def get_key_val(text):
    match = re.search("k=(\"|')(.+)(\"|') v=(\"|')(.*?)(\"|')", text)
    return {"k": match.group(2), "v": match.group(5)}


# タグが閉じているか確認
def is_end_tag(text):
    match = re.search("/(.*)>", text)
    print(match)
    return


# 引数の地点が領域内か確認
def is_inside(lat, lon):
    global bounds

    if bounds["minlat"] <= lat <= bounds["maxlat"]:
        if bounds["minlon"] <= lon <= bounds["maxlon"]:
            return True
    return False


# OSMファイルを解析
def parse_osm(filepath):
    global bounds
    global headers
    global highway_vals
    global nodes
    global ways

    way = {}

    # プログレスバーを作成
    widgets = ["Parse OSM-file: ", progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = sum(1 for line in open(filepath)), term_width = 80)
    counter = 0

    # ファイルを1行ずつ読み込み
    for line in open(filepath, "r"):

        # 空白文字を削除
        text = line.strip()

        if len(text) > 0:
            tag = get_tag(text)

            if (tag == "?xml") or (tag == "osm") or (tag == "note") or (tag == "meta") or (tag == "bounds"):
                if tag == "bounds":
                    bounds = get_bounds(text)
                else:
                    headers[tag] = text
            elif tag == "node":
                if get_action(text) is not None:
                    lat = get_lat(text)
                    lon = get_lon(text)
                    if is_inside(lat, lon):
                        nid = get_id(text)
                        ver = get_version(text)
                        nodes[nid] = {"id": nid, "lat": lat, "lon": lon, "ver": ver}
                    continue
            elif tag == "way":
                way["id"] = get_id(text)
                way["ver"] = get_version(text)
                way["nds"] = []
                way["tag"] = {}
            elif tag == "nd":
                way["nds"].append(get_ref(text))
            elif tag == "tag":
                if "tag" in way:
                    kv = get_key_val(text)
                    if kv["k"] == "highway":
                        if kv["v"] in highway_vals:
                            way["tag"]["highway"] = kv["v"]
                    elif kv["k"] == "oneway":
                        if kv["v"] in oneway_vals["yes"]:
                            way["tag"]["oneway"] = "yes"
                        elif kv["v"] in oneway_vals["-1"]:
                            way["tag"]["oneway"] = "-1"
            elif tag == "/way":
                if "highway" in way["tag"]:
                    if ("oneway" in way["tag"]) and (way["tag"]["oneway"] == "-1"):
                        way["nds"].reverse()
                        way["tag"]["oneway"] = "yes"
                    if len(way["nds"]) > 1:
                        ways[way["id"]] = way
                    way = {}

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    # プログレスバーを削除
    progress.finish()


# リンク数を計算
def calc_num_links():
    global ways

    total = 0
    for way in ways.values():
        if ("oneway" in way["tag"]) and (way["tag"]["oneway"] == "1"):
            total += (len(way["nds"]) - 1)
        else:
            total += ((len(way["nds"]) - 1) * 2)

    return total


# node集合に存在しないnodeを要素にもつリンクを削除
def del_links(msg):
    global nodes
    global ways

    ret = {"before": calc_num_links(), "after": None}

    # プログレスバーを作成
    widgets = ["{}: ".format(msg), progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = len(ways), term_width = 80)
    counter = 0

    del_keys = []
    for way in ways.values():

        # node集合に存在するか確認
        for i in range(len(way["nds"]))[::-1]:
            if way["nds"][i] not in nodes:
                way["nds"].pop(i)

        # 無効なwayか確認
        if len(way["nds"]) < 2:
            del_keys.append(way["id"])

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    # 無効なwayを削除
    for key in del_keys:
        ways.pop(key)

    # プログレスバーを削除
    progress.finish()

    ret["after"] = calc_num_links()
    return ret


# 距離0のリンクを削除
def del_zero_length_links():
    global nodes
    global ways

    ret = {"before": calc_num_links(), "after": None}

    # プログレスバーを作成
    widgets = ["Delete zero length links: ", progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = len(ways), term_width = 80)
    counter = 0

    del_keys = []
    for way in ways.values():
        for i in range(1, len(way["nds"]))[::-1]:
            snode = nodes[way["nds"][i - 1]]
            enode = nodes[way["nds"][i]]
            if calc_hubeny(snode["lat"], snode["lon"], enode["lat"], enode["lon"]) == 0.0:
                way["nds"].pop(i)

        if len(way["nds"]) < 2:
            del_keys.append(way["id"])

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    for key in del_keys:
        ways.pop(key)

    # プログレスバーを削除
    progress.finish()

    ret["after"] = calc_num_links()
    return ret


# 最大の強連結成分のnodeを取得
def calc_scc_nodes():
    global nodes
    global ways

    # プログレスバーを作成
    widgets = ["Calculate SCC nodes: ", progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = len(nodes) + len(ways), term_width = 80)
    counter = 0

    # networkxのグラフを作成
    graph = nx.DiGraph()

    # グラフにノードを追加
    for nid in nodes.keys():
        graph.add_node(nid)
        counter += 1
        progress.update(counter)

    # グラフにリンクを追加
    for wid, way in ways.items():
        size = len(way["nds"])
        for i in range(size - 1):
            graph.add_edge(way["nds"][i], way["nds"][i + 1])
        if "oneway" not in way["tag"]:
            for i in range(1, size)[::-1]:
                graph.add_edge(way["nds"][i], way["nds"][i - 1])
        counter += 1
        progress.update(counter)

    # 最大の強連結成分を取得
    scc = max(nx.strongly_connected_component_subgraphs(graph), key = len)

    # プログレスバーを削除
    progress.finish()

    return scc.nodes()


# 最大の強連結成分に含まれていないnodeを削除
def del_unconnected_nodes(scc_nodes):
    global nodes

    ret = {"before": len(nodes), "after": None}

    # プログレスバーを作成
    widgets = ["Delete unconnected nodes: ", progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = len(nodes), term_width = 80)
    counter = 0

    del_keys = []
    for nid in nodes.keys():

        # 強連結成分に含まれていないnodeを確認
        if nid not in scc_nodes:
            del_keys.append(nid)

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    # nodeを削除
    for key in del_keys:
        nodes.pop(key)

    # プログレスバーを削除
    progress.finish()

    ret["after"] = len(nodes)
    return ret


# ndsからdel_flagに従ってノードを削除した場合の最大誤差を計算
def calc_max_diff(nds, del_flag, meter):
    global nodes

    # 削除ノードとその前後のノードを確認
    triangle_list = []
    prev = 0
    for i in range(1, len(nds)):
        if del_flag[i]:
            triangle_list.append([prev, i])
        else:
            for triangle in triangle_list:
                if len(triangle) == 2:
                    triangle.append(i)
            prev = i

    # 誤差を計算
    max_diff = -1.0
    max_diff_index = None
    for triangle in triangle_list:
        n1 = nodes[nds[triangle[0]]]
        n2 = nodes[nds[triangle[1]]]
        n3 = nodes[nds[triangle[2]]]
        l1 = calc_hubeny(n2["lat"], n2["lon"], n3["lat"], n3["lon"])
        l2 = calc_hubeny(n1["lat"], n1["lon"], n3["lat"], n3["lon"])
        l3 = calc_hubeny(n1["lat"], n1["lon"], n2["lat"], n2["lon"])
        elem = (l1 + l2 + l3) * (- l1 + l2 + l3) * (l1 - l2 + l3) * (l1 + l2 - l3)
        diff = 0.0
        if elem > 0.0:
            diff = math.sqrt(elem) / (2.0 * l2)
        if diff > max_diff:
            max_diff = diff
            max_diff_index = triangle[1]

    return {"diff": max_diff, "index": max_diff_index}


# ndsからdel_flagに従ってノードを削除する場合の最良の削除ノードの組み合わせを計算
def update_del_flag_greedily(nds, del_flag, meter):
    result = calc_max_diff(nds, del_flag, meter)
    if result["diff"] >= meter:
        del_flag[result["index"]] = False
        update_del_flag_greedily(nds, del_flag, meter)


# ノードを削除してリンク数を削減
def del_straight_nodes(degree, meter):
    global nodes
    global ways

    ret = {"node": {}, "link": {}}
    ret["node"] = {"before": len(nodes), "after": None}
    ret["link"] = {"before": calc_num_links(), "after": None}
    radian = degree * math.pi / 180.0

    # プログレスバーを作成
    widgets = ["Delete straight nodes: ", progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = len(ways) * 2, term_width = 80)
    counter = 0

    # あるnodeが含まれているwayの数を確認
    nid_ways = {}
    for way in ways.values():
        size = len(way["nds"])
        for i in range(size):
            nd = way["nds"][i]
            if (i == 0) or (i == size - 1):
                nid_ways[nd] = 2
            elif nd in nid_ways:
                nid_ways[nd] += 1
            else:
                nid_ways[nd] = 1

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    # wayごとにノードを削除
    for wid in sorted(ways.keys()):
        way = ways[wid]
        size = len(way["nds"])
        del_flag = []

        # 削除する候補ノードを確認
        for i in range(size):
            nd = way["nds"][i]
            flag = True
            if (i == 0) or (i == size - 1) or (nid_ways[nd] > 1):
                flag = False
            if flag:
                prev_nd = way["nds"][i - 1]
                next_nd = way["nds"][i + 1]
                l1 = calc_hubeny(nodes[nd]["lat"], nodes[nd]["lon"], nodes[next_nd]["lat"], nodes[next_nd]["lon"])
                l2 = calc_hubeny(nodes[prev_nd]["lat"], nodes[prev_nd]["lon"], nodes[next_nd]["lat"], nodes[next_nd]["lon"])
                l3 = calc_hubeny(nodes[prev_nd]["lat"], nodes[prev_nd]["lon"], nodes[nd]["lat"], nodes[nd]["lon"])
                cos = (l1 * l1 + l3 * l3 - l2 * l2) / (2.0 * l1 * l3)
                if cos < -1.0:
                    cos = -1.0
                elif cos > 1.0:
                    cos = 1.0
                theta = math.acos(cos)

                if theta < radian:
                    flag = False
            del_flag.append(flag)

        # 削除ノードの組み合わせを更新
        update_del_flag_greedily(way["nds"], del_flag, meter)

        # ノードを削除
        for i in range(size)[::-1]:
            if del_flag[i]:
                nd = way["nds"][i]
                way["nds"].pop(i)
                nodes.pop(nd)

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    # プログレスバーを削除
    progress.finish()

    ret["node"]["after"] = len(nodes)
    ret["link"]["after"] = calc_num_links()
    return ret


# 道路網に関係ないnodeを削除
def del_useless_nodes():
    global nodes
    global ways

    ret = {"before": len(nodes), "after": None}

    # プログレスバーを作成
    widgets = ["Delete useless nodes: ", progressbar.Percentage(), " ", progressbar.Bar(), " ", progressbar.Timer()]
    progress = progressbar.ProgressBar(widgets = widgets, max_value = len(nodes), term_width = 80)
    counter = 0

    del_keys = []
    for nid in nodes.keys():

        # wayに含まれていれば有効
        enable = False
        for way in ways.values():
            if nid in way["nds"]:
                enable = True
                break
        if not enable:
            del_keys.append(nid)

        # プログレスバーを更新
        counter += 1
        progress.update(counter)

    for key in del_keys:
        nodes.pop(key)

    # プログレスバーを削除
    progress.finish()

    ret["after"] = len(nodes)
    return ret


# 出力ファイルパスを取得
def get_output_filepath(filepath, degree, meter):
    return "{}_{}_{}.osm".format(re.search("(.+).osm", filepath).group(1), degree, meter)


# 新しいOSMファイルを出力
def write_enable_osm_file(filepath):
    global bounds
    global headers
    global nodes
    global ways

    f = open(filepath, "w")

    # 道路網以外のデータを出力
    f.write("{}\n".format(headers["?xml"]))
    f.write("{}\n".format(headers["osm"]))
    if "note" in headers:
        f.write("  {}\n".format(headers["note"]))
    if "meta" in headers:
        f.write("  {}\n".format(headers["meta"]))
    f.write("  <bounds minlat=\"{:.4f}\" minlon=\"{:.4f}\" maxlat=\"{:.4f}\" maxlon=\"{:.4f}\"/>\n".format(bounds["minlat"], bounds["minlon"], bounds["maxlat"], bounds["maxlon"]))

    # nodeを出力
    for nid, node in sorted(nodes.items()):
        if node["ver"] is None:
            f.write("  <node id=\"{}\" lat=\"{:.7f}\" lon=\"{:.7f}\" version=\"1\"/>\n".format(node["id"], node["lat"], node["lon"]))
        else:
            f.write("  <node id=\"{}\" lat=\"{:.7f}\" lon=\"{:.7f}\" version=\"{}\"/>\n".format(node["id"], node["lat"], node["lon"], node["ver"]))

    # wayを出力
    for wid, way in sorted(ways.items()):
        if way["ver"] is None:
            f.write("  <way id=\"{}\" version=\"1\">\n".format(way["id"]))
        else:
            f.write("  <way id=\"{}\" version=\"{}\">\n".format(way["id"], way["ver"]))
        for nd in way["nds"]:
            f.write("    <nd ref=\"{}\"/>\n".format(nd))
        f.write("    <tag k=\"highway\" v=\"{}\"/>\n".format(way["tag"]["highway"]))
        if "oneway" in way["tag"]:
            f.write("    <tag k=\"oneway\" v=\"yes\"/>\n")
        f.write("  </way>\n")

    f.write("</osm>\n")
    f.close()


##########################
##                      ##
##    ここからメイン    ##
##                      ##
##########################


# コマンドライン引数を処理
args = parse_args()

# 保存するhighwayキーの値を設定
set_highway_vals()

# 一方通行の値を設定
set_oneway_vals()

# OSMファイルを解析
parse_osm(args.osm[0])

# 領域外に延びているリンクを削除
num = del_links("Delete outside links")
print("link: {} -> {}".format(num["before"], num["after"]))

# 距離0のリンクを削除
num = del_zero_length_links()
print("link: {} -> {}".format(num["before"], num["after"]))

# 最大の強連結成分に含まれていないnodeを削除
num = del_unconnected_nodes(calc_scc_nodes())
print("node: {} -> {}".format(num["before"], num["after"]))

# 最大の強連結成分に含まれていないリンクを削除
num = del_links("Delete unconnected links")
print("link: {} -> {}".format(num["before"], num["after"]))

# ノードを削除してリンク数を削減
if (args.degree < 180) and (args.meter > 0):
    num = del_straight_nodes(args.degree, args.meter)
    print("node: {} -> {}".format(num["node"]["before"], num["node"]["after"]))
    print("link: {} -> {}".format(num["link"]["before"], num["link"]["after"]))

# 道路網に関係ないnodeを削除
num = del_useless_nodes()
print("node: {} -> {}".format(num["before"], num["after"]))

# 新しいOSMファイルを出力
write_enable_osm_file(get_output_filepath(args.osm[0], args.degree, args.meter))

