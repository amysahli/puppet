require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'

require 'matchers/resource'

describe 'the run_plan function' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files
  include Matchers::Resource

  context "when invoked" do
    let(:env_name) { 'testenv' }
    let(:environments_dir) { Puppet[:environmentpath] }
    let(:env_dir) { File.join(environments_dir, env_name) }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
    let(:node) { Puppet::Node.new("test", :environment => env) }
    let(:env_dir_files) {
      {
        'modules' => {
          'test' => {
            'plans' => {
               'run_me.pp' => 'plan test::run_me() { "worked2" }'
            }
          }
        }
      }
    }

    let(:populated_env_dir) do
      dir_contained_in(environments_dir, env_name => env_dir_files)
      PuppetSpec::Files.record_tmp(env_dir)
      env_dir
    end

    context 'can be called as' do
      it 'run_plan(name) referencing a plan defined in the manifest' do
        expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[worked1]')
            plan run_me() { "worked1" }
            $a = run_plan('run_me')
            notify { $a: }
          CODE
      end

      it 'run_plan(name) referencing an autoloaded plan in a module' do
        expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[worked2]')
            $a = run_plan('test::run_me')
            notify { $a: }
          CODE
      end

      it 'run_plan(name, hash) where hash is mapping argname to value' do
        expect(compile_to_catalog(<<-CODE, node)).to have_resource('Notify[worked3]')
            plan run_me($x) { $x }
            $a = run_plan('run_me', {x=>'worked3'})
            notify { $a: }
          CODE
      end
    end

    context 'handles exceptions by' do
      it 'failing with error for non-existent plan name' do
        expect { compile_to_catalog(<<-CODE) }.to raise_error(Puppet::Error, /Unknown plan/)
          $a = run_plan('not_a_plan_name')
          notify { $a: }
        CODE
      end

      it 'failing with type mismatch error if given args does not match parameters' do
        expect { compile_to_catalog(<<-CODE) }.to raise_error(Puppet::Error, /expects an Integer value/)
          plan run_me(Integer $x) { $x }
          $a = run_plan('run_me', {x=>'should not work'})
        CODE
      end

    end
  end
end